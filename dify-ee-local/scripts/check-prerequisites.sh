#!/bin/bash
# Check prerequisites for Dify EE local deployment

set -e

echo "Checking prerequisites..."
echo ""

check_command() {
    local cmd=$1
    local min_version=$2
    local name=$3

    if command -v "$cmd" &> /dev/null; then
        version=$($cmd version 2>/dev/null | head -1 || $cmd --version 2>/dev/null | head -1)
        echo "✅ $name: $version"
        return 0
    else
        echo "❌ $name: not found"
        return 1
    fi
}

failed=0

check_command "docker" "20.10" "Docker" || failed=1
check_command "kubectl" "1.24" "kubectl" || failed=1
check_command "helm" "3.0" "Helm" || failed=1
check_command "kind" "0.20" "Kind" || failed=1

echo ""

if [ $failed -eq 0 ]; then
    echo "✅ All prerequisites satisfied!"
else
    echo "❌ Some prerequisites are missing. Please install them before proceeding."
    exit 1
fi
