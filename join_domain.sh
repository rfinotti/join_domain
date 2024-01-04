#!/bin/bash
#Script crated by Riccardo Finotti
# Log file
log_file="join_domain.log"

# Check if a domain controller is resolvable
check_domain_resolution() {
  local domain_controller_fqdn="$domain_to_join"
  
  if ! host "$domain_controller_fqdn" &> /dev/null; then
    echo "Error: Domain controller ($domain_controller_fqdn) is not resolvable."
    read -p "Enter the primary internal DNS IP address: " dns_ip
    echo "# Domain Controller ipv4:" | sudo tee -a /etc/hosts
    echo "$dns_ip $domain_to_join" | sudo tee -a /etc/hosts
    echo "Added $domain_to_join with IP $dns_ip to /etc/hosts." >> "$log_file"
  else
    echo "Domain controller is resolvable."
  fi
}

install_dependencies() {
  local dependencies=("realmd" "sssd" "sssd-tools" "libnss-sss" "libpam-sss" "adcli" "samba-common-bin" "oddjob" "oddjob-mkhomedir" "packagekit")

  for dep in "${dependencies[@]}"; do
    if ! dpkg -s "$dep" &> /dev/null; then
      echo "Installing $dep..."
      if ! sudo apt-get update; then
        echo "Failed to update package lists."
        exit 1
      fi
      if ! sudo apt-get install -y "$dep"; then
        echo "Failed to install $dep."
        exit 1
      fi
    else
      echo "$dep is already installed."
    fi
  done
}

# Prompt user for domain admin user, password, and domain to join
read -p "Enter Domain Admin user: " domain_admin_user
echo
read -p "Enter Domain to join: " domain_to_join

# Check if already joined to the domain
if realm list | grep -q "$domain_to_join"; then
  echo "Already joined to $domain_to_join."
  exit 0
fi

# Perform dependency check and install
install_dependencies
realm discover $domain_to_join

# Check domain network connectivity
if ping -c 1 "$domain_to_join" &> /dev/null; then
  echo "Connected to the domain network."

  # Edit Kerberos configuration
  sudo sh -c "echo \"default_realm = $domain_to_join\" > /etc/krb5.conf"

  # Join the domain
  sudo realm join --user="$domain_admin_user@$domain_to_join" "$domain_to_join"
  
  # Verify ID and attributes from the domain controller
  id "$domain_admin_user@$domain_to_join"
  
  # Edit SSSD configuration
  sudo sh -c "echo -e \"[sssd]\ndomains = $domain_to_join\nconfig_file_version = 2\nservices = nss, pam\nuse_fully_qualified_names = False\" > /etc/sssd/sssd.conf"

  # Restart SSSD service
  sudo service sssd restart

  # Create home directory for the user
  echo "session optional pam_mkhomedir.so skel=/etc/skel umask=077" | sudo tee -a /etc/pam.d/common-session

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
      echo "$name is now an administrator of the PC."
    fi
  fi

  echo "Domain Joined."

else
  echo "Not connected to the domain network."
  check_domain_resolution
  echo "Domain Join failed. See $log_file for details."
fi
