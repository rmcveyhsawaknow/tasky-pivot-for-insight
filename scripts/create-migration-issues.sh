#!/usr/bin/env bash
# ==============================================================================
# CREATE PHASE 1 GITHUB ISSUES FOR AWS-TO-AZURE MIGRATION
# ==============================================================================
# This script creates GitHub issues from the Phase 1 research findings
# and associates them with the project board for Kanban tracking.
#
# Prerequisites:
#   - gh CLI authenticated: gh auth login
#   - Repository context: run from repo root
#
# Usage:
#   chmod +x scripts/create-migration-issues.sh
#   ./scripts/create-migration-issues.sh
#
# Project Board: https://github.com/users/rmcveyhsawaknow/projects/8
# ==============================================================================

set -euo pipefail

REPO="rmcveyhsawaknow/tasky-pivot-for-insight"
PROJECT_NUMBER=8
PROJECT_OWNER="rmcveyhsawaknow"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================================"
echo "  AWS-to-Azure Migration: Phase 1 Issue Creation"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Ensure required labels exist
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Step 1: Creating required labels...${NC}"

declare -A LABELS
LABELS=(
  ["phase:assessment"]="Phase 1 - Assessment tasks|c5def5"
  ["phase:service-mapping"]="Phase 2 - Service mapping tasks|0075ca"
  ["phase:iac-development"]="Phase 3 - IaC development tasks|008672"
  ["phase:cicd-updates"]="Phase 4 - CI/CD update tasks|e4e669"
  ["phase:validation"]="Phase 5 - Validation tasks|d876e3"
  ["task:documentation"]="Documentation deliverables|fbca04"
  ["task:research"]="Research and analysis tasks|b60205"
  ["task:development"]="Code or IaC development tasks|1d76db"
  ["task:configuration"]="Configuration tasks|5319e7"
  ["task:testing"]="Testing and validation tasks|0e8a16"
  ["task:validation"]="Verification tasks|006b75"
  ["migration:aws-to-azure"]="AWS to Azure PaaS migration project|d93f0b"
  ["priority:high"]="High priority|b60205"
  ["priority:medium"]="Medium priority|fbca04"
)

for label in "${!LABELS[@]}"; do
  IFS='|' read -r description color <<< "${LABELS[$label]}"
  if gh label create "$label" --repo "$REPO" --description "$description" --color "$color" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Created label: $label${NC}"
  else
    echo -e "  ${YELLOW}• Label exists: $label${NC}"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Step 2: Get Project ID for issue association
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Step 2: Looking up project ID...${NC}"

PROJECT_ID=$(gh api graphql -f query='
  query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        id
      }
    }
  }
' -f owner="$PROJECT_OWNER" -F number="$PROJECT_NUMBER" --jq '.data.user.projectV2.id' 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}  ✗ Could not find project #$PROJECT_NUMBER. Issues will be created without project association.${NC}"
  echo "  You can manually add them at: https://github.com/users/$PROJECT_OWNER/projects/$PROJECT_NUMBER"
else
  echo -e "  ${GREEN}✓ Project ID: $PROJECT_ID${NC}"
fi

echo ""

# ---------------------------------------------------------------------------
# Helper function to create an issue and add it to the project
# ---------------------------------------------------------------------------
create_issue() {
  local title="$1"
  local body_file="$2"
  local labels="$3"

  echo -e "${YELLOW}  Creating issue: $title${NC}"

  # Create the issue
  ISSUE_URL=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body-file "$body_file" \
    --label "$labels" \
    2>/dev/null)

  if [ -z "$ISSUE_URL" ]; then
    echo -e "  ${RED}✗ Failed to create issue: $title${NC}"
    return 1
  fi

  echo -e "  ${GREEN}✓ Created: $ISSUE_URL${NC}"

  # Add to project if we have a project ID
  if [ -n "$PROJECT_ID" ]; then
    ISSUE_NODE_ID=$(gh api "$(echo "$ISSUE_URL" | sed 's|https://github.com/|repos/|')" --jq '.node_id' 2>/dev/null || echo "")

    if [ -n "$ISSUE_NODE_ID" ]; then
      gh api graphql -f query='
        mutation($project: ID!, $contentId: ID!) {
          addProjectV2ItemById(input: {projectId: $project, contentId: $contentId}) {
            item { id }
          }
        }
      ' -f project="$PROJECT_ID" -f contentId="$ISSUE_NODE_ID" > /dev/null 2>&1 && \
        echo -e "  ${GREEN}  ✓ Added to project board${NC}" || \
        echo -e "  ${YELLOW}  • Could not add to project (add manually)${NC}"
    fi
  fi

  echo ""
}

# ---------------------------------------------------------------------------
# Step 3: Create Phase 1 issues
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Step 3: Creating Phase 1 - Assessment issues...${NC}"
echo ""

ISSUES_DIR="docs/migration/issues"

# Issue 1.1 - Document Current Application Architecture
create_issue \
  "[Migration] 1.1 - Document Current Application Architecture" \
  "$ISSUES_DIR/phase1-task1.1-document-application-architecture.md" \
  "migration:aws-to-azure,phase:assessment,task:documentation,priority:high"

# Issue 1.2 - Inventory Current AWS Infrastructure as Code
create_issue \
  "[Migration] 1.2 - Inventory Current AWS Infrastructure as Code" \
  "$ISSUES_DIR/phase1-task1.2-inventory-aws-iac.md" \
  "migration:aws-to-azure,phase:assessment,task:documentation,priority:high"

# Issue 1.3 - Inventory GitHub Actions CI/CD Workflows
create_issue \
  "[Migration] 1.3 - Inventory GitHub Actions CI/CD Workflows" \
  "$ISSUES_DIR/phase1-task1.3-inventory-cicd-workflows.md" \
  "migration:aws-to-azure,phase:assessment,task:documentation,priority:high"

# Issue 1.4 - Document Current Tagging and Billing Strategy
create_issue \
  "[Migration] 1.4 - Document Current Tagging and Billing Strategy" \
  "$ISSUES_DIR/phase1-task1.4-document-tagging-billing.md" \
  "migration:aws-to-azure,phase:assessment,task:documentation,priority:medium"

# Issue 1.5 - Identify Application Configuration Dependencies
create_issue \
  "[Migration] 1.5 - Identify Application Configuration Dependencies" \
  "$ISSUES_DIR/phase1-task1.5-identify-config-dependencies.md" \
  "migration:aws-to-azure,phase:assessment,task:documentation,priority:high"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "============================================================"
echo "  Phase 1 Issue Creation Complete"
echo "============================================================"
echo ""
echo "  Project Board: https://github.com/users/$PROJECT_OWNER/projects/$PROJECT_NUMBER"
echo "  Issues List:   https://github.com/$REPO/issues?q=label%3Aphase%3Aassessment"
echo ""
echo "  Next Steps:"
echo "  1. Review issues on the project board"
echo "  2. Assign issues to team members or Copilot agent"
echo "  3. Run Phase 2 issue creation when Phase 1 is complete"
echo ""
