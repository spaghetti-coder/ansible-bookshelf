#!/usr/bin/env bash

# Suppress some spellcheck and prevent samples from execution
# shellcheck disable=SC2317,SC2002
return 2>/dev/null || exit 0

#
# PREREQS:
# =======
# * SSH_HOST has 'openssh-server' or another SSH server installed
#

# Generate SSH key.
# SSH_HOST can be _.target.fqdn.local to signify wildcard
install -d -m 0700 ~/.ssh/SSH_HOST  `# <- Replace placeholders` \
&& ssh-keygen -t rsa -b 4096 -q -N "" \
  -C "$(id -un)@$(hostname -f)"     `# <- Replace with nice comment if needed` \
  -f ~/.ssh/SSH_HOST/SSH_USER       `# <- Replace placeholders`

# Create local SSH config file
cat << EOF | sed -e 's/\s*$//' \
    > ~/.ssh/SSH_HOST/SSH_USER.config     `# <- Replace placeholders`
# SSH host match pattern. Samples:
#   myserv.com                            # <- Straight match
#   *.myserv.com myserv.com myserv2.com   # <- Multi-wildcard match
Host SSH_HOST                             `# <- Replace placeholders`
  # The actual SSH host. Samples:
  #   10.0.0.69, google.com, %h           # <- %h refers to the matched Host
  HostName %h                             `# <- Replace if needed`
  # Port 22                               `# <- Uncomment and change if needed`
  User SSH_USER                           `# <- Replace placeholders`
  IdentityFile ~/.ssh/SSH_HOST/SSH_USER   `# <- Replace placeholders`
  IdentitiesOnly yes
EOF

# Append local to main SSH config file
echo "Include ~/.ssh/SSH_HOST/SSH_USER.config"  `# <- Replace placeholders` \
  >> ~/.ssh/config

# Copy to SSH host
ssh-copy-id -i ~/.ssh/SSH_HOST/SSH_USER SSH_USER@SSH_HOST   `# <- Replace placeholders`

# Alternative (insecure) copy to SSH host
cat ~/.ssh/SSH_HOST/SSH_USER.pub | ssh SSH_USER@SSH_HOST    `# <- Replace placeholders` \
  'tee -a ~/.ssh/authorized_keys'
