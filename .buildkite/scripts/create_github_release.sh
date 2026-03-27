#!/bin/bash
set -e

GREEN="\033[0;32m"
NC="\033[0m"
logger() {
  echo -e "${GREEN}$(date "+%Y/%m/%d %H:%M:%S") create_github_release.sh: $1${NC}"
}

# Install gh CLI if not present
if ! command -v gh &> /dev/null; then
  logger "Installing gh CLI"
  GH_VERSION="2.65.0"
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" -o /tmp/gh.tar.gz
  tar -xzf /tmp/gh.tar.gz -C /tmp
  sudo mv "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh
  rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_amd64"
fi

# Generate a short-lived GitHub App installation token
# Requires GH_APP_ID and GH_APP_PRIVATE_KEY environment variables in Buildkite
generate_jwt() {
  local app_id="$1"
  local private_key="$2"
  local now=$(date +%s)
  local iat=$((now - 60))
  local exp=$((now + 600))

  local header=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
  local payload=$(echo -n "{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${app_id}\"}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
  local unsigned="${header}.${payload}"
  local signature=$(echo -n "$unsigned" | openssl dgst -sha256 -sign <(echo "$private_key") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

  echo "${unsigned}.${signature}"
}

logger "Generating GitHub App installation token"
JWT=$(generate_jwt "$GH_APP_ID" "$GH_APP_PRIVATE_KEY")

INSTALLATION_ID=$(curl -fsSL \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/antiwork/gumroad/installation" | ruby -e "require 'json'; puts JSON.parse(STDIN.read)['id']")

GH_TOKEN=$(curl -fsSL \
  -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens" | ruby -e "require 'json'; puts JSON.parse(STDIN.read)['token']")

export GH_TOKEN

COMMIT_SHA=${BUILDKITE_COMMIT}

# Determine calendar version tag (vYYYY.MM.DD.N)
TODAY=$(date -u +%Y.%m.%d)

# Fetch existing tags for today to determine sequence number
git fetch --tags --force > /dev/null 2>&1
EXISTING_TAGS=$(git tag -l "v${TODAY}.*" | sort -t. -k4 -n)

if [ -z "$EXISTING_TAGS" ]; then
  SEQUENCE=1
else
  LAST_SEQUENCE=$(echo "$EXISTING_TAGS" | tail -1 | rev | cut -d. -f1 | rev)
  SEQUENCE=$((LAST_SEQUENCE + 1))
fi

VERSION_TAG="v${TODAY}.${SEQUENCE}"

# Find the previous release tag for changelog range
PREVIOUS_TAG=$(git tag -l "v*.*.*.*" | sort -t. -k1,1 -k2,2n -k3,3n -k4,4n | tail -1)

logger "Creating GitHub Release ${VERSION_TAG} at commit ${COMMIT_SHA}"

# Create and push the git tag
git tag "$VERSION_TAG" "$COMMIT_SHA"
git push origin "$VERSION_TAG"

# Create the GitHub Release
if [ -n "$PREVIOUS_TAG" ]; then
  logger "Generating changelog from ${PREVIOUS_TAG} to ${VERSION_TAG}"
  gh release create "$VERSION_TAG" --target "$COMMIT_SHA" --generate-notes --notes-start-tag "$PREVIOUS_TAG"
else
  logger "No previous release found, creating initial release for commit ${COMMIT_SHA}"
  COMMIT_TITLE=$(git log -1 --pretty=format:'%s' "$COMMIT_SHA")
  gh release create "$VERSION_TAG" --target "$COMMIT_SHA" --notes "Initial release.

* ${COMMIT_TITLE} (${COMMIT_SHA:0:12})"
fi

logger "GitHub Release ${VERSION_TAG} created successfully"
