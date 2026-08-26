#!/usr/bin/env bash
# Deploy Permis LB to GitHub Pages.
#
#   ./deploy.sh                      -> https://<you>.github.io/permis-lb/
#   ./deploy.sh permis-lb exam.me.com -> same, but served on your own domain
#
# Prerequisite (run once, opens a browser):  gh auth login

set -euo pipefail

REPO="${1:-permis-lb}"
DOMAIN="${2:-}"
# --user-site resolves to <your-login>.github.io, so the shortest URL works
# regardless of what the GitHub username actually is.
USER_SITE=0
[ "$REPO" = "--user-site" ] && { USER_SITE=1; REPO=""; }
GH="/c/Program Files/GitHub CLI/gh.exe"
[ -x "$GH" ] || GH="$(command -v gh)"

cd "$(dirname "$0")"

if ! "$GH" auth status >/dev/null 2>&1; then
  echo "Not logged in to GitHub. Run this first, then re-run deploy:"
  echo "    gh auth login"
  exit 1
fi

USER=$("$GH" api user --jq .login)
echo "==> GitHub user: $USER"
[ "$USER_SITE" = "1" ] && REPO="$USER.github.io"
echo "==> Repo name: $REPO"

# A custom domain is served only if a CNAME file ships with the site.
if [ -n "$DOMAIN" ]; then
  echo "$DOMAIN" > CNAME
  echo "==> CNAME set to $DOMAIN"
else
  rm -f CNAME
fi

git add -A
git diff --cached --quiet || git -c commit.gpgsign=false commit -q -m "Deploy Permis LB to GitHub Pages"

if "$GH" repo view "$USER/$REPO" >/dev/null 2>&1; then
  echo "==> Repo $USER/$REPO already exists, pushing to it"
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$USER/$REPO.git"
else
  echo "==> Creating public repo $USER/$REPO"
  "$GH" repo create "$REPO" --public --source=. --remote=origin \
    --description="Lebanese driving theory practice exam - 340 official questions in Arabic, French and English"
fi

git push -u origin main --force

echo "==> Enabling GitHub Pages (branch main, root)"
"$GH" api -X POST "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || "$GH" api -X PUT "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || echo "    (Pages may already be enabled - continuing)"

if [ -n "$DOMAIN" ]; then
  "$GH" api -X PUT "repos/$USER/$REPO/pages" -f "cname=$DOMAIN" -F "https_enforced=true" >/dev/null 2>&1 \
    || echo "    (Set the custom domain in Settings > Pages if this failed)"
fi

echo
echo "Done. GitHub takes about a minute to build the site."
if [ -n "$DOMAIN" ]; then
  echo "  Site:  https://$DOMAIN"
  echo "  Add these DNS records at your domain registrar:"
  case "$DOMAIN" in
    *.*.*) echo "    CNAME  ${DOMAIN%%.*}  ->  $USER.github.io" ;;
    *)     echo "    A  @  185.199.108.153"
           echo "    A  @  185.199.109.153"
           echo "    A  @  185.199.110.153"
           echo "    A  @  185.199.111.153" ;;
  esac
  echo "  HTTPS turns on automatically once DNS resolves (can take a few hours)."
elif [ "$REPO" = "$USER.github.io" ]; then
  echo "  Site:  https://$USER.github.io"
else
  echo "  Site:  https://$USER.github.io/$REPO/"
fi
