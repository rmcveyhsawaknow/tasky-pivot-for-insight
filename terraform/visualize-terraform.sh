#!/bin/bash
# Terraform Visualization Script
# Handles multiple visualization methods with fallbacks

set -e

PLAN_FILE="terraform.tfplan"
OUTPUT_DIR="terraform-visualizations"

echo "🔍 Terraform Visualization Tool"
echo "================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if plan file exists
if [[ ! -f "$PLAN_FILE" ]]; then
    echo "❌ Plan file $PLAN_FILE not found."
    echo "   Please run: terraform plan -out=$PLAN_FILE"
    exit 1
fi

echo "📊 Generating graph files..."

# Generate basic Terraform graphs
terraform graph -plan="$PLAN_FILE" > "$OUTPUT_DIR/terraform-graph.dot"
terraform graph -plan="$PLAN_FILE" -type=plan > "$OUTPUT_DIR/terraform-plan-graph.dot"
terraform graph -plan="$PLAN_FILE" -type=apply > "$OUTPUT_DIR/terraform-apply-graph.dot"

echo "✅ DOT files generated in $OUTPUT_DIR/"

# Convert to visual formats with Graphviz
if command -v dot >/dev/null 2>&1; then
    echo "🎨 Converting to visual formats..."
    
    # Generate multiple formats for main graph
    dot -Tpng "$OUTPUT_DIR/terraform-graph.dot" -o "$OUTPUT_DIR/terraform-graph.png"
    dot -Tsvg "$OUTPUT_DIR/terraform-graph.dot" -o "$OUTPUT_DIR/terraform-graph.svg"
    dot -Tpdf "$OUTPUT_DIR/terraform-graph.dot" -o "$OUTPUT_DIR/terraform-graph.pdf"
    
    # Generate plan-specific visualizations
    dot -Tpng "$OUTPUT_DIR/terraform-plan-graph.dot" -o "$OUTPUT_DIR/terraform-plan.png"
    dot -Tsvg "$OUTPUT_DIR/terraform-plan-graph.dot" -o "$OUTPUT_DIR/terraform-plan.svg"
    
    # Generate apply-specific visualizations
    dot -Tpng "$OUTPUT_DIR/terraform-apply-graph.dot" -o "$OUTPUT_DIR/terraform-apply.png"
    dot -Tsvg "$OUTPUT_DIR/terraform-apply-graph.dot" -o "$OUTPUT_DIR/terraform-apply.svg"
    
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
