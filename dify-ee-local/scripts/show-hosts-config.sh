#!/bin/bash
# Display hosts configuration for Dify EE local deployment

echo "Add the following to /etc/hosts:"
echo ""
echo "# Dify Local Development"
echo "127.0.0.1 console.dify.local"
echo "127.0.0.1 app.dify.local"
echo "127.0.0.1 api.dify.local"
echo "127.0.0.1 enterprise.dify.local"
echo "127.0.0.1 files.dify.local"
echo "127.0.0.1 trigger.dify.local"
echo ""
echo "---"
echo "Command to add (requires sudo):"
echo ""
cat << 'EOF'
sudo bash -c 'cat >> /etc/hosts << HOSTS

# Dify Local Development
127.0.0.1 console.dify.local
127.0.0.1 app.dify.local
127.0.0.1 api.dify.local
127.0.0.1 enterprise.dify.local
127.0.0.1 files.dify.local
127.0.0.1 trigger.dify.local
HOSTS'
EOF
