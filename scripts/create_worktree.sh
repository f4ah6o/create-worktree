#!/bin/bash
set -euo pipefail

# ... (Colors and Logging functions are fine, keep them) ...
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ... (Usage function is fine) ...

# Check arguments
if [ $# -lt 1 ]; then
    echo "Feature name is required"
    exit 1
fi

FEATURE_NAME="$1"

# --- 【修正 1】入力値のバリデーション (重要) ---
# 英数字、ハイフン、アンダースコアのみ許可し、パス区切り文字(/)を拒否する
if [[ ! "$FEATURE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid feature name. Only alphanumeric, hyphens, and underscores are allowed."
    exit 1
fi

BRANCH_NAME="feature/${FEATURE_NAME}"
WORKTREE_DIR=".worktrees/${FEATURE_NAME}"

# Get the root directory of the repository
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# --- 【修正 2】gitignore のチェック ---
if ! grep -q ".worktrees" .gitignore; then
    log_warn ".worktrees is not in .gitignore!"
    log_warn "Please add '.worktrees/' to .gitignore to prevent committing secrets."
    # ここで exit 1 しても良いですが、一旦警告に留めています
fi

# ... (Git checks and worktree creation logic is fine) ...

log_info "Creating worktree for feature: ${FEATURE_NAME}"
if [ ! -d ".git" ]; then
    log_error "Not a git repository"
    exit 1
fi

if [ -d "${WORKTREE_DIR}" ]; then
    log_error "Worktree already exists: ${WORKTREE_DIR}"
    exit 1
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    log_warn "Branch ${BRANCH_NAME} already exists"
    git worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}"
else
    log_step "Creating new branch and worktree..."
    git worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" main
fi

# ... (Port generation is fine for dev use) ...

copy_if_exists() {
    local src="$1"
    local dest="$2"
    if [ -f "${src}" ]; then
        # --- 【修正 3】コピー先ディレクトリの保証 ---
        mkdir -p "$(dirname "${dest}")"
        cp "${src}" "${dest}"
        log_info "Copied: ${src}"
    fi
}

# Root level environment files
if [ -f ".env" ]; then
    # Generate random ports (Keep logic, it's okay for dev)
    RANDOM_FRONTEND_PORT=$((RANDOM % 50000 + 10000))
    RANDOM_BACKEND_PORT=$((RANDOM % 50000 + 10000))
    RANDOM_AGENT_PORT=$((RANDOM % 50000 + 10000))

    # .worktrees ディレクトリ自体の存在確認（git worktree add で作られるはずだが念のため）
    mkdir -p "${WORKTREE_DIR}"

    sed -e "s/^FRONTEND_PORT=.*/FRONTEND_PORT=${RANDOM_FRONTEND_PORT}/" \
        -e "s/^BACKEND_PORT=.*/BACKEND_PORT=${RANDOM_BACKEND_PORT}/" \
        -e "s/^AGENT_PORT=.*/AGENT_PORT=${RANDOM_AGENT_PORT}/" \
        ".env" > "${WORKTREE_DIR}/.env"

    log_info "Copied: .env (with randomized ports)"
fi

# ... (Rest of file copying and Makefile logic is fine) ...
copy_if_exists ".envrc" "${WORKTREE_DIR}/.envrc"

FRONTEND_FILES=(".env" ".env.local" ".env.dev" ".env.prd" ".env.test")
for file in "${FRONTEND_FILES[@]}"; do
    copy_if_exists "modules/frontend/${file}" "${WORKTREE_DIR}/modules/frontend/${file}"
done

copy_if_exists "modules/backend/.env" "${WORKTREE_DIR}/modules/backend/.env"
copy_if_exists "modules/agent/.env" "${WORKTREE_DIR}/modules/agent/.env"

log_info "Environment files copied"

# Run make setup
cd "${WORKTREE_DIR}"
if [ -f "Makefile" ]; then
    make setup || log_warn "make setup completed with warnings"
else 
    log_warn "No Makefile found"
fi

# Print summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Worktree created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Location: ${REPO_ROOT}/${WORKTREE_DIR}"
echo "Branch:   ${BRANCH_NAME}"
echo ""
echo "To start working:"
echo "  cd ${WORKTREE_DIR}"
echo ""
echo "To remove worktree when done:"
echo "  git worktree remove ${WORKTREE_DIR}"
echo ""
