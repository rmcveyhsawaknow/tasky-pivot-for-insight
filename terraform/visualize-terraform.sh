#!/bin/bash
# Terraform Visualization Script
# Handles multiple visualization methods with fallbacks and stale plan detection

set -e

PLAN_FILE="terraform.tfplan"
OUTPUT_DIR="terraform-visualizations"

echo "🔍 Terraform Visualization Tool"
echo "================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to check if plan is stale
check_plan_staleness() {
    if [[ ! -f "$PLAN_FILE" ]]; then
        return 1  # Plan doesn't exist
    fi
    
    # Test if plan is stale by trying to run terraform graph
    if ! terraform graph -plan="$PLAN_FILE" >/dev/null 2>&1; then
        return 2  # Plan is stale
    fi
    
    return 0  # Plan is valid
}

# Function to generate fresh plan
generate_fresh_plan() {
    echo "🔄 Generating fresh plan..."
    if terraform plan -out="$PLAN_FILE" >/dev/null 2>&1; then
        echo "✅ Fresh plan generated successfully"
        return 0
    else
        echo "❌ Failed to generate fresh plan"
        return 1
    fi
}

# Function to generate current state graph (without plan)
generate_current_state_graph() {
    echo "📊 Generating current state graph..."
    terraform graph > "$OUTPUT_DIR/terraform-current-state.dot"
    echo "✅ Current state graph generated"
}

# Check plan status
echo "🔍 Checking plan status..."
check_result=$(check_plan_staleness; echo $?)

case $check_result in
    1)
        echo "❌ Plan file $PLAN_FILE not found."
        echo "   Options:"
        echo "   1. Generate fresh plan: terraform plan -out=$PLAN_FILE"
        echo "   2. Visualize current state only (no plan needed)"
        echo ""
        read -p "Generate fresh plan now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if generate_fresh_plan; then
                echo "✅ Proceeding with fresh plan..."
            else
                echo "❌ Plan generation failed. Generating current state graph only..."
                generate_current_state_graph
                exit 1
            fi
        else
            echo "📊 Generating current state graph only..."
            generate_current_state_graph
            # Continue with current state visualization only
            PLAN_FILE=""
        fi
        ;;
    2)
        echo "⚠️  Plan file is STALE (state changed since plan was created)"
        echo "   Plan created: $(stat -c %y "$PLAN_FILE" 2>/dev/null || echo 'unknown')"
        echo "   State modified: $(stat -c %y terraform.tfstate 2>/dev/null || echo 'unknown')"
        echo ""
        echo "   Options:"
        echo "   1. Generate fresh plan for accurate visualization"
        echo "   2. Visualize current state only (recommended)"
        echo "   3. Continue anyway (may show outdated information)"
        echo ""
        read -p "Choose option (1/2/3): " -n 1 -r
        echo
        case $REPLY in
            1)
                if generate_fresh_plan; then
                    echo "✅ Proceeding with fresh plan..."
                else
                    echo "❌ Plan generation failed. Generating current state graph only..."
                    generate_current_state_graph
                    PLAN_FILE=""
                fi
                ;;
            2)
                echo "📊 Generating current state graph only..."
                generate_current_state_graph
                PLAN_FILE=""
                ;;
            3)
                echo "⚠️  Proceeding with stale plan (results may be inaccurate)..."
                # Continue with existing stale plan
                ;;
            *)
                echo "📊 Defaulting to current state graph only..."
                generate_current_state_graph
                PLAN_FILE=""
                ;;
        esac
        ;;
    0)
        echo "✅ Plan file is valid and current"
        ;;
esac

echo ""
echo "📊 Generating graph files..."

if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    echo "📋 Using plan file: $PLAN_FILE"
    # Generate plan-based graphs
    terraform graph -plan="$PLAN_FILE" > "$OUTPUT_DIR/terraform-graph.dot"
    terraform graph -plan="$PLAN_FILE" -type=plan > "$OUTPUT_DIR/terraform-plan-graph.dot"  
    terraform graph -plan="$PLAN_FILE" -type=apply > "$OUTPUT_DIR/terraform-apply-graph.dot"
else
    echo "📊 Using current state only"
    # Generate current state graph
    if [[ ! -f "$OUTPUT_DIR/terraform-current-state.dot" ]]; then
        terraform graph > "$OUTPUT_DIR/terraform-current-state.dot"
    fi
    # Copy current state as main graph for consistency
    cp "$OUTPUT_DIR/terraform-current-state.dot" "$OUTPUT_DIR/terraform-graph.dot"
fi

echo "✅ DOT files generated in $OUTPUT_DIR/"

# Convert to visual formats with Graphviz
if command -v dot >/dev/null 2>&1; then
    echo "🎨 Converting to visual formats..."
    
    # Generate multiple formats for main graph
    dot -Tpng "$OUTPUT_DIR/terraform-graph.dot" -o "$OUTPUT_DIR/terraform-graph.png"
    dot -Tsvg "$OUTPUT_DIR/terraform-graph.dot" -o "$OUTPUT_DIR/terraform-graph.svg"
    dot -Tpdf "$OUTPUT_DIR/terraform-graph.dot" -o "$OUTPUT_DIR/terraform-graph.pdf"
    
    # Generate plan-specific visualizations only if plan files exist
    if [[ -f "$OUTPUT_DIR/terraform-plan-graph.dot" ]]; then
        dot -Tpng "$OUTPUT_DIR/terraform-plan-graph.dot" -o "$OUTPUT_DIR/terraform-plan.png"
        dot -Tsvg "$OUTPUT_DIR/terraform-plan-graph.dot" -o "$OUTPUT_DIR/terraform-plan.svg"
    fi
    
    # Generate apply-specific visualizations only if apply files exist
    if [[ -f "$OUTPUT_DIR/terraform-apply-graph.dot" ]]; then
        dot -Tpng "$OUTPUT_DIR/terraform-apply-graph.dot" -o "$OUTPUT_DIR/terraform-apply.png"
        dot -Tsvg "$OUTPUT_DIR/terraform-apply-graph.dot" -o "$OUTPUT_DIR/terraform-apply.svg"
    fi
    
    echo "✅ Static visualizations created!"
else
    echo "⚠️  Graphviz not installed. Skipping image generation."
fi

# Try inframap if available
if [[ -f "./inframap-linux-amd64" ]]; then
    echo "🗺️  Generating inframap visualization..."
    ./inframap-linux-amd64 generate --hcl . > "$OUTPUT_DIR/inframap.dot"
    if command -v dot >/dev/null 2>&1; then
        dot -Tsvg "$OUTPUT_DIR/inframap.dot" -o "$OUTPUT_DIR/inframap.svg"
        dot -Tpng "$OUTPUT_DIR/inframap.dot" -o "$OUTPUT_DIR/inframap.png"
    fi
    echo "✅ Inframap visualization generated!"
fi

# Generate enhanced DOT with better formatting
cat > "$OUTPUT_DIR/enhanced-graph.dot" << 'EOF'
digraph {
    rankdir = "LR";
    node [shape = "box", style = "filled", color = "lightblue"];
    edge [color = "darkgray"];
EOF

# Append the original graph content (removing the first line)
tail -n +2 "$OUTPUT_DIR/terraform-graph.dot" >> "$OUTPUT_DIR/enhanced-graph.dot"

if command -v dot >/dev/null 2>&1; then
    dot -Tsvg "$OUTPUT_DIR/enhanced-graph.dot" -o "$OUTPUT_DIR/enhanced-graph.svg"
    dot -Tpng "$OUTPUT_DIR/enhanced-graph.dot" -o "$OUTPUT_DIR/enhanced-graph.png"
fi

# Create simple HTML viewer
cat > "$OUTPUT_DIR/viewer.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Terraform Plan Visualization</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .section { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .graph { text-align: center; margin: 20px 0; }
        img { max-width: 100%; height: auto; border: 1px solid #ccc; }
        .download-links { margin: 10px 0; }
        .download-links a { margin: 0 10px; padding: 5px 10px; background: #007cba; color: white; text-decoration: none; border-radius: 3px; }
        .download-links a:hover { background: #005a87; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Terraform Plan Visualization</h1>
        
        <div class="section">
            <h2>📊 Main Infrastructure Graph</h2>
            <div class="graph">
                <img src="terraform-graph.svg" alt="Terraform Graph" onerror="this.src='terraform-graph.png'">
            </div>
            <div class="download-links">
                <a href="terraform-graph.svg" download>Download SVG</a>
                <a href="terraform-graph.png" download>Download PNG</a>
                <a href="terraform-graph.pdf" download>Download PDF</a>
                <a href="terraform-graph.dot" download>Download DOT</a>
            </div>
        </div>

        <div class="section">
            <h2>📋 Plan Changes Graph</h2>
            <div class="graph">
                <img src="terraform-plan.svg" alt="Terraform Plan Graph" onerror="this.src='terraform-plan.png'">
            </div>
            <div class="download-links">
                <a href="terraform-plan.svg" download>Download SVG</a>
                <a href="terraform-plan.png" download>Download PNG</a>
                <a href="terraform-plan-graph.dot" download>Download DOT</a>
            </div>
        </div>

        <div class="section">
            <h2>🚀 Apply Operations Graph</h2>
            <div class="graph">
                <img src="terraform-apply.svg" alt="Terraform Apply Graph" onerror="this.src='terraform-apply.png'">
            </div>
            <div class="download-links">
                <a href="terraform-apply.svg" download>Download SVG</a>
                <a href="terraform-apply.png" download>Download PNG</a>
                <a href="terraform-apply-graph.dot" download>Download DOT</a>
            </div>
        </div>

        <div class="section">
            <h2>🎨 Enhanced Graph</h2>
            <div class="graph">
                <img src="enhanced-graph.svg" alt="Enhanced Terraform Graph" onerror="this.src='enhanced-graph.png'">
            </div>
            <div class="download-links">
                <a href="enhanced-graph.svg" download>Download SVG</a>
                <a href="enhanced-graph.png" download>Download PNG</a>
                <a href="enhanced-graph.dot" download>Download DOT</a>
            </div>
        </div>
    </div>
</body>
</html>
EOF

echo ""
echo "🎉 Visualization complete!"
echo "📁 All files saved to: $OUTPUT_DIR/"
echo "🌐 Open viewer.html in your browser for interactive viewing"
echo ""
echo "Generated files:"
ls -la "$OUTPUT_DIR"/ | grep -E '\.(svg|png|pdf|html|dot)$' | while read line; do
    echo "   📄 $line"
done

echo ""
echo "🔗 To view in browser:"
echo "   file://$(pwd)/$OUTPUT_DIR/viewer.html"

# Try to open in Simple Browser if in VS Code
if [[ -n "$VSCODE_CWD" ]]; then
    echo ""
    echo "💡 VS Code detected. You can use the Simple Browser to view the results!"
fi
