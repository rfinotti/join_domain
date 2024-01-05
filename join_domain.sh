#!/bin/bash
# Script created by Riccardo Finotti

# Log files
error_log="join_error.log"
run_log="join_run.log"

# Function to log messages
log_message() {
  local log_file="$1"
  local message="$2"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | sudo tee -a "$log_file"
}

# Function to handle errors
handle_error() {
  local error_message="$1"
  log_message "$error_log" "Error: $error_message"
  log_message "$run_log" "Script execution failed. See $error_log for details."
  exit 1
}

# Function to install dependencies
install_dependencies() {
  local dependencies=("realmd" "sssd" "sssd-tools" "libnss-sss" "libpam-sss" "adcli" "samba-common-bin" "oddjob" "oddjob-mkhomedir" "packagekit")

  for dep in "${dependencies[@]}"; do
    if ! dpkg -s "$dep" &> /dev/null; then
      log_message "$run_log" "Installing $dep..."
      if ! sudo apt-get update; then
        handle_error "Failed to update package lists."
      fi
      if ! sudo apt-get install -y "$dep"; then
        handle_error "Failed to install $dep."
      fi
    else
      log_message "$run_log" "$dep is already installed."
    fi
  done
}

# Create run log
log_message "$run_log" "Script execution started."

# Prompt user for domain admin user, password, and domain to join
read -p "Enter Domain Admin user: " domain_admin_user
echo
read -p "Enter Domain to join (must be written in capital letters): " domain_to_join

# Check if already joined to the domain
if realm list | grep -q "$domain_to_join"; then
  log_message "$run_log" "Already joined to $domain_to_join."
  exit 0
fi

# Perform dependency check and install
install_dependencies
realm discover $domain_to_join

# Check domain network connectivity
if ping -c 1 "$domain_to_join" &> /dev/null; then
  log_message "$run_log" "Connected to the domain network."

  # Edit Kerberos configuration
  sudo sh -c "echo \"default_realm = $domain_to_join\" > /etc/krb5.conf"

  # Join the domain
  if ! sudo realm join --user="$domain_admin_user@$domain_to_join $domain_to_join"; then
    handle_error "Failed to join the domain."
  fi

  # Ask user if they know who will use this PC
  read -p "Do you already know who will use this PC? (y/n): " knows_user

  if [ "$knows_user" == "y" ]; then
    # Indicate who will be the main user for this PC
    read -p "Enter domain user's first name (composite names must be entered without spaces): " name
    read -p "Enter domain user's last name (composite names must be entered without no spaces): " last_name
    
    # Convert to pre-Windows 2000 format "name.last_name"
    username="$name.$last_name"
    
    # Verify ID and attributes from the domain controller
    id "$username@$domain_to_join"

    # Ask user for administrator role
    read -p "Do you want $name to be an administrator of the PC? (y/n): " is_admin

    if [ "$is_admin" == "y" ]; then
      # Add user to sudo and root groups
      sudo usermod -aG sudo "$username"
      sudo usermod -aG root "$username"
      log_message "$run_log" "$name is now an administrator of the PC."
    fi
  fi

  # Create home directory for the user
  echo "session optional pam_mkhomedir.so skel=/etc/skel umask=077" | sudo tee -a /etc/pam.d/common-session

  # Edit SSSD configuration
  sudo sed -i "s/use_fully_qualified_names = True/use_fully_qualified_names = False/" /etc/sssd/sssd.conf

  # Edit the workgroup smb.conf
  sudo sed -i "s/workgroup = WORKGROUP/workgroup = $domain_to_join/" /etc/samba/smb.conf

  # Edit user lookup in NSSWITCH.CONF
  sudo sed -i "s/passwd: files systemd/passwd: compat sss systemd/" /etc/nsswitch.conf

  # Restart SSSD service
  if ! sudo service sssd restart; then
    handle_error "Failed to restart SSSD service."
  fi

else
  log_message "$run_log" "Not connected to the domain network."
  check_domain_resolution
  handle_error "Domain Join failed."
fi

# Log success and exit
log_message "$run_log" "Script execution completed successfully."
exit 0
