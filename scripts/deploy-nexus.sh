#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

BUILD_DIR="$ROOT_DIR/build"
DEPLOY_DIR="$SCRIPT_DIR/deploy"

M2_DEFAULT="$HOME/.m2/settings.xml"

mkdir -p "$BUILD_DIR"
mkdir -p "$DEPLOY_DIR"

clear
echo "===================================================="
echo "        HELM CHART BUILD & NEXUS DEPLOYMENT         "
echo "===================================================="

# ------------------------------------------------------------------
# STEP 1 - Load Nexus Config
# ------------------------------------------------------------------

echo "[1/7] Loading Nexus configuration..."

DEPLOY_M2_FILE="$DEPLOY_DIR/settings.xml"

# Jika settings.xml sudah ada di deploy folder
if [ -f "$DEPLOY_M2_FILE" ]; then

    echo "[OK] Using cached settings.xml from deploy folder"
    M2_PATH="$DEPLOY_M2_FILE"

else

    echo "[INFO] settings.xml not found in deploy folder"

    read -p "Enter path to Maven settings.xml [Default: ~/.m2/settings.xml]: " USER_M2

    M2_PATH=${USER_M2:-$M2_DEFAULT}

    if [ ! -f "$M2_PATH" ]; then
        echo "[ERROR] settings.xml not found!"
        exit 1
    fi

    echo "[INFO] Copying settings.xml to deploy directory..."

    cp "$M2_PATH" "$DEPLOY_M2_FILE"

    M2_PATH="$DEPLOY_M2_FILE"

fi

echo "[OK] settings.xml ready"

# Extract Nexus URL
NEXUS_URL=$(grep -A 5 "<id>nexus</id>" "$M2_PATH" | grep "<url>" | sed 's/.*<url>\(.*\)<\/url>.*/\1/' | xargs)

if [ -z "$NEXUS_URL" ]; then
    echo "[ERROR] Nexus URL not found!"
    exit 1
fi

# Extract Credentials
NEXUS_USER=$(grep -A 5 "<id>nexus</id>" "$M2_PATH" | grep "<username>" | sed 's/.*<username>\(.*\)<\/username>.*/\1/' | xargs)
NEXUS_PASS=$(grep -A 5 "<id>nexus</id>" "$M2_PATH" | grep "<password>" | sed 's/.*<password>\(.*\)<\/password>.*/\1/' | xargs)

if [ -z "$NEXUS_USER" ]; then
    echo "[ERROR] Nexus credentials not found!"
    exit 1
fi

echo "[OK] Nexus credentials loaded"

# Parse Host & Port
if [[ $NEXUS_URL =~ http?://([^:/]+):?([0-9]*) ]]; then

    NEXUS_HOST=${BASH_REMATCH[1]}

    if [ -n "${BASH_REMATCH[2]}" ]; then
        NEXUS_PORT=${BASH_REMATCH[2]}
    else
        NEXUS_PORT=80
    fi

else
    echo "[ERROR] Unable to parse Nexus URL"
    exit 1
fi

echo "[OK] Nexus Host: $NEXUS_HOST"
echo "[OK] Nexus Port: $NEXUS_PORT"

# ------------------------------------------------------------------
# STEP 2 - Read Chart.yaml
# ------------------------------------------------------------------

echo ""
echo "[2/6] Reading Chart.yaml..."

CHART_FILE="$ROOT_DIR/Chart.yaml"

if [ ! -f "$CHART_FILE" ]; then
    echo "[ERROR] Chart.yaml not found!"
    exit 1
fi

CHART_NAME=$(grep "^name:" "$CHART_FILE" | awk '{print $2}')
CURRENT_VERSION=$(grep "^version:" "$CHART_FILE" | awk '{print $2}')

if [ -z "$CURRENT_VERSION" ]; then
    echo "[ERROR] Version not found in Chart.yaml"
    exit 1
fi

echo "[OK] Chart Name    : $CHART_NAME"
echo "[OK] Current Ver   : $CURRENT_VERSION"

# ------------------------------------------------------------------
# STEP 3 - Choose Version Increment
# ------------------------------------------------------------------

echo ""
echo "[3/6] Choose version increment type"
echo "------------------------------------"
echo "1) MAJOR  (X.0.0)"
echo "2) MINOR  (X.Y.0)"
echo "3) PATCH  (X.Y.Z)"
echo ""

read -p "Select option [1-3] (Default: 3): " VERSION_OPTION
VERSION_OPTION=${VERSION_OPTION:-3}

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case $VERSION_OPTION in

1)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    INCREMENT_TYPE="MAJOR"
    ;;

2)
    MINOR=$((MINOR + 1))
    PATCH=0
    INCREMENT_TYPE="MINOR"
    ;;

3)
    PATCH=$((PATCH + 1))
    INCREMENT_TYPE="PATCH"
    ;;

*)
    echo "[ERROR] Invalid option"
    exit 1
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "[OK] Increment Type : $INCREMENT_TYPE"
echo "[OK] New Version    : $NEW_VERSION"

# ------------------------------------------------------------------
# STEP 4 - Update Chart.yaml
# ------------------------------------------------------------------

echo ""
echo "[4/6] Updating Chart.yaml..."

sed -i "s/version: $CURRENT_VERSION/version: $NEW_VERSION/" "$CHART_FILE"

echo "[OK] Chart.yaml updated"

# ------------------------------------------------------------------
# STEP 5 - Helm Package
# ------------------------------------------------------------------

echo ""
echo "[5/6] Packaging Helm chart..."

PACKAGE_OUTPUT=$(helm package "$ROOT_DIR" --destination "$BUILD_DIR")

PACKAGE_FILE=$(echo "$PACKAGE_OUTPUT" | awk '{print $NF}')
PACKAGE_NAME=$(basename "$PACKAGE_FILE")

echo "[OK] Package created:"
echo "     $PACKAGE_NAME"

# ------------------------------------------------------------------
# STEP 6 - Upload to Nexus
# ------------------------------------------------------------------

echo ""
echo "[6/6] Uploading chart to Nexus..."

UPLOAD_URL="http://$NEXUS_HOST:$NEXUS_PORT/repository/helm-internal/"

curl -u "$NEXUS_USER:$NEXUS_PASS" \
     --upload-file "$BUILD_DIR/$PACKAGE_NAME" \
     "$UPLOAD_URL"

echo "[OK] Upload successful"

# ------------------------------------------------------------------
# STEP 7 - Git Commit & Push
# ------------------------------------------------------------------

echo ""
echo "[7/7] Updating Git repository..."

cd "$ROOT_DIR"

# Check if git repo exists
if [ ! -d ".git" ]; then
    echo "[WARN] Not a git repository. Skipping git commit."
else

    git add Chart.yaml

    git commit -m "deploy - new version ${NEW_VERSION}" || echo "[INFO] Nothing to commit"

    echo "[INFO] Pushing changes to remote..."

    git push

    echo "[OK] Git repository updated"
fi

# ------------------------------------------------------------------
# FINISH
# ------------------------------------------------------------------

echo ""
echo "===================================================="
echo "           HELM CHART DEPLOYMENT SUCCESS            "
echo "===================================================="
echo ""
echo "Chart        : $CHART_NAME"
echo "Version      : $NEW_VERSION"
echo "Package File : $BUILD_DIR/$PACKAGE_NAME"
echo "Repository   : $UPLOAD_URL"
echo "===================================================="
echo ""