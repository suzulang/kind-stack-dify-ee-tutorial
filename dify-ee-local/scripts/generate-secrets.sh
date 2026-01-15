#!/bin/bash
# Generate secrets for Dify EE deployment

echo "Generating secrets for Dify EE..."
echo ""

echo "global.appSecretKey:"
openssl rand -base64 42
echo ""

echo "enterprise.appSecretKey:"
openssl rand -base64 42
echo ""

echo "enterprise.adminAPIsSecretKeySalt:"
openssl rand -base64 42
echo ""

echo "---"
echo "Copy these values to your values.yaml file."
