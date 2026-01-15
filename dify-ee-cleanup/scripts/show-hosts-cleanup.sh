#!/bin/bash
# Display hosts cleanup command for Dify EE

echo "To remove Dify hosts entries, run:"
echo ""
echo "sudo sed -i '' '/dify.local/d' /etc/hosts"
echo ""
echo "Or manually edit /etc/hosts and remove these lines:"
echo "127.0.0.1 console.dify.local"
echo "127.0.0.1 app.dify.local"
echo "127.0.0.1 api.dify.local"
echo "127.0.0.1 enterprise.dify.local"
echo "127.0.0.1 files.dify.local"
echo "127.0.0.1 trigger.dify.local"
