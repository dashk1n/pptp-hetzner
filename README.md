# PPTP VPN Server Management Tool

A set of tools for easily creating and managing PPTP VPN servers on Hetzner Cloud infrastructure. This project automates the deployment and configuration of PPTP VPN servers using Ansible and Hetzner Cloud CLI.

## Overview

This tool allows you to:

- Quickly provision new VPS instances on Hetzner Cloud
- Automatically configure PPTP VPN servers
- Manage multiple PPTP servers with different configurations
- Set up VPN users and passwords

## Prerequisites

- [Hetzner Cloud CLI](https://github.com/hetznercloud/cli) (`hcloud`)
- Hetzner Cloud API token
- Ansible (for automated server configuration)
- SSH key for server access

## Project Structure

```
bclient.sh           # Main management script
notes.txt            # Development notes and examples
servers.txt          # Configuration file for VPN servers
ansible/             # Ansible playbooks and configurations
  bclient-vars.yml.example   # Example variables file
  hosts.example      # Example Ansible hosts file
  pptpd.yml          # Ansible playbook for PPTP configuration
  templates/         # Jinja2 templates for configuration files
    chap-secrets.j2  # VPN user authentication template
    pptpd-options.j2 # PPTP options template
    pptpd.j2         # PPTP server configuration template
assets/              # Project assets
  bclient-ssh-key    # SSH private key
  bclient-ssh-key.pub # SSH public key
```

## Setup

1. Clone this repository
2. Generate an SSH key pair for server access and Ansible automation (if not already done):
   ```bash
   ssh-keygen -t rsa -b 4096 -f assets/bclient-ssh-key
   ```
   
   This key will be used both for SSH access to the servers and by Ansible for automated configuration.

3. Download the Hetzner Cloud CLI tool:
   ```bash
   # For example, Linux 64-bit:
   curl -L https://github.com/hetznercloud/cli/releases/download/v1.15.0/hcloud-linux-amd64.tar.gz | tar xz
   ```

4. Create a Hetzner Cloud context with your API token:
   ```bash
   ./hcloud context create bclient
   ```

5. Upload your SSH key to Hetzner Cloud:
   ```bash
   ./hcloud ssh-key create --name bclient-ssh-key1 --public-key-from-file=assets/bclient-ssh-key.pub
   ```

## Usage

### Server Configuration

Edit the `servers.txt` file to define your VPN server configurations:

```
# Format: SERVER_NAME LOCAL_IP REMOTE_IP-RANGE PPTP_USER PPTP_PASS SERVER_IP
test1 192.168.0.1 192.168.0.150-150 user1 pass1 94.130.27.53
```

Each line represents a VPN server configuration with the following fields:
- `SERVER_NAME`: Name for your server instance
- `LOCAL_IP`: Local IP address for the VPN server
- `REMOTE_IP-RANGE`: IP range for VPN clients
- `PPTP_USER`: VPN username
- `PPTP_PASS`: VPN password
- `SERVER_IP`: Public IP address of the server (will be filled automatically when created)

### Managing Servers

To manage your PPTP VPN servers:

1. **Add or Remove Servers**:
   - Edit the `servers.txt` file to add new server configurations or remove existing ones
   - Each line in the file represents one VPN server

2. **Apply Changes**:
   - Run the management script to apply your changes:
     ```bash
     ./bclient.sh
     ```
   - The script will read the `servers.txt` file and create, update, or remove servers accordingly

3. **Automate with Cron** (Recommended):
   - Set up a cron job to periodically run the script and ensure your server configuration stays in sync:
     ```bash
     # Run the script every hour
     0 * * * * /path/to/bclient.sh > /path/to/bclient.log 2>&1
     ```
   - Edit your crontab with `crontab -e` and add the above line
   - Adjust the frequency based on your needs (hourly, daily, etc.)

This automated approach ensures that your server configuration always matches what's defined in your `servers.txt` file, making it easy to manage multiple servers.

## Ansible Configuration

The project uses Ansible to automate the configuration of PPTP servers. The main playbook is `ansible/pptpd.yml`, which:

1. Installs the PPTP server package
2. Configures PPTP with the appropriate settings
3. Sets up user authentication
4. Configures IP forwarding
5. Starts and enables the PPTP service

## Security Considerations

Please note that PPTP has known security vulnerabilities and is not recommended for highly secure applications. Consider using more secure VPN protocols (like OpenVPN or WireGuard) for production environments.