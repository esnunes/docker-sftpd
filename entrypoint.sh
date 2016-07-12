#!/bin/bash
set -e

userConfPath="/etc/sftp-users.conf"
userConfFinalPath="/var/run/sftp-users.conf"

function createUser() {
    IFS=':' read -a param <<< $@
    user="${param[0]}"
    pass="${param[1]}"

    if [ "${param[2]}" == "e" ]; then
        chpasswdOptions="-e"
        uid="${param[3]}"
        gid="${param[4]}"
    else
        uid="${param[2]}"
        gid="${param[3]}"
    fi

    if [ -z "$user" ]; then
        echo "FATAL: You must at least provide a username."
        exit 1
    fi

    if $(cat /etc/passwd | cut -d: -f1 | grep -q "$user"); then
        echo "FATAL: User \"$user\" already exists."
        exit 2
    fi

    mkdir -p /home/$user

    useraddOptions="-h /home/$user"

    if [ -n "$uid" ]; then
        useraddOptions="$useraddOptions -u $uid"
    fi

    if [ -n "$gid" ]; then
        if ! $(cat /etc/group | cut -d: -f3 | grep -q "$gid"); then
            addgroup -g $gid -S $gid
        fi

        useraddOptions="$useraddOptions -G $gid"
    fi

    adduser $useraddOptions -S $user

    if [ -z "$pass" ]; then
        pass="$(tr -dc A-Za-z0-9 </dev/urandom | head -c256)"
        chpasswdOptions=""
    fi

    echo "$user:$pass" | chpasswd $chpasswdOptions

    # Add SSH keys to authorized_keys with valid permissions
    if [ -d /home/$user/.ssh/keys ]; then
        cat /home/$user/.ssh/keys/* >> /home/$user/.ssh/authorized_keys
        chown $user /home/$user/.ssh/authorized_keys
        chmod 600 /home/$user/.ssh/authorized_keys
    fi

    chown root:root /home/$user
    chmod 755 /home/$user

    mkdir -p /home/$user/files
    chown $user:$gid /home/$user/files
}

# Create users only on first run
if [ ! -f "$userConfFinalPath" ]; then

    # Append mounted config to final config
    if [ -f "$userConfPath" ]; then
        cat "$userConfPath" | grep -v -e '^$' > "$userConfFinalPath"
    fi

    # Append users from arguments to final config
    for user in "$@"; do
        echo "$user" >> "$userConfFinalPath"
    done

    # Append users from STDIN to final config
    if [ ! -t 0 ]; then
        while IFS= read -r user || [[ -n "$user" ]]; do
            echo "$user" >> "$userConfFinalPath"
        done
    fi

    # Check that we have users in config
    if [ "$(cat "$userConfFinalPath" | wc -l)" == 0 ]; then
        echo "FATAL: No users provided!"
        exit 3
    fi

    # Import users from final conf file
    while IFS= read -r user || [[ -n "$user" ]]; do
        createUser "$user"
    done < "$userConfFinalPath"

    if ls /keys/ssh_host_*key* 1> /dev/null 2>&1; then
        cp -a /keys/ssh_host_*key* /etc/ssh/
    else
        # Generate unique ssh keys for this container
        ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -q -N ""
        ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -q -N ""
        ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -q -N ""
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -q -N ""
	cp -a /etc/ssh/ssh_host_*key* /keys/
    fi
fi

# Source custom scripts, if any
if [ -d /etc/sftp.d ]; then
    for f in /etc/sftp.d/*; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

exec /usr/sbin/sshd -D -e
