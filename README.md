 # Join Domain Script

This script automates the process of joining a Linux machine to a Windows Active Directory domain. It is specifically designed for Linux bases OS (Desktop and Server) and provides an interactive setup for domain join, user configuration, and other related tasks.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Script Details](#script-details)
- [Author](#author)
- [License](#license)

## Features

- Interactive domain join setup.
- Dependency check and installation.
- Configuration of Kerberos and SSSD.
- User creation and administrator role assignment.
- Logging of errors and domain join status.

## Prerequisites

- Linux based OS
- Sudo privileges
- Active Directory domain details (admin user, password, domain name)
- Internal DNS IP address for domain resolution

## Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/rfinotti/join-domain-script.git

2. Navigate to the script directory:
   ```bash
   cd join-domain-script

3. Make the script executable:
   ```bash
   chmod +x join_domain.sh

4. Run the script:
   ```bash
   ./join_domain.sh

5. Follow the interactive prompts to complete the domain join process.

## Script Details
  - check_domain_resolution: Checks if the domain controller is resolvable and adds the necessary entry to /etc/hosts if not.
  - install_dependencies: Installs required dependencies for domain join.
  - Usage: Prompts the user for domain admin user, password, and domain to join. Checks if the machine is already joined to the domain.
  - realm discover: Discovers the realm/domain information.
  - Kerberos Configuration: Edits the Kerberos configuration file.
  - realm join: Joins the Linux machine to the specified domain.
  - SSSD Configuration: Edits the SSSD configuration file.
  - Restart SSSD service: Restarts the SSSD service.
  - Create home directory: Adds a configuration entry for creating home directories.
  - User Configuration: Prompts the user for information about the main user for the PC and assigns administrator roles if desired.

## Author
  Riccardo Finotti
  GitHub: rfinotti

## License
    This project is licensed under the MIT License.
