#!/bin/bash

cd "$(dirname "$0")"

SCRIPT_HOME=$(pwd)
ASSETS="${SCRIPT_HOME}/assets"
ANSIBLE_SCRIPT_HOME='./ansible'

SSH_KEY_FILE="${ASSETS}/bclient-ssh-key"
# you have to add ssh-key to hcloud context in advance
SSH_KEY_NAME="bclient-ssh-key1"
SERVER_TYPE='cx11'
DISTRO="ubuntu-18.04"


# create vm on hetzner with hcloud cli tool and return ip address of server that has been created
create_server()
{
    NAME=$1
    ./hcloud server create --name $NAME --image "${DISTRO}" --type "${SERVER_TYPE}" --ssh-key "${SSH_KEY_NAME}" | awk 'END{print $2}'
}

delete_server()
{
    NAME=$1
    ./hcloud server delete ${NAME}
}

# this function is user variables SERVER_NAME SERVER_IP LOCAL_IP REMOTE_IP PPTP_USER PPTP_PASS
# they must be configured previousely
setup_ansible()
{
    cat <<EOF >${ANSIBLE_SCRIPT_HOME}/hosts
[pptp]
${SERVER_NAME} ansible_host=${SERVER_IP} ansible_connection=ssh ansible_user=root ansible_ssh_private_key_file=${SSH_KEY_FILE}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

    cat <<EOF >${ANSIBLE_SCRIPT_HOME}/bclient-vars.yml
server_name: ${SERVER_NAME}
local_ip: ${LOCAL_IP}
remote_ip: ${REMOTE_IP}
pptp_user: ${PPTP_USER}
pptp_pass: ${PPTP_PASS}
EOF

}

# setup_pptpd SERVER_NAME SERVER_IP LOCAL_IP REMOTE_IP PPTP_USER PPTP_PASS
run_ansible()
{
    cd ${ANSIBLE_SCRIPT_HOME}
    eval ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_SSH_RETRIES=10 ansible-playbook  pptpd.yml -i hosts
    cd ${SCRIPT_HOME}
}

main()
{
    SERVER_LIST_FILE=$1
    COUNT_CREATED_SERVERS=0
    COUNT_DELETED_SERVERS=0

    EXISTED_SERVERS=($(./hcloud server list | awk '{if (NR!=1) {printf "%s ",$2}}'))
    IFS=$'\r\n' command eval  'DESIRED_SERVERS=($(cat $SERVER_LIST_FILE | grep -v "^#"))'

    # check if server from DESIRED_SERVERS doesn't contained in EXISTED_SERVERS
    for SERVER in "${DESIRED_SERVERS[@]}"
    do
        # convert string to array of server's params
        CREATED_SERVER_PARAMS=($(echo ${SERVER}))

        SERVER_NAME=${CREATED_SERVER_PARAMS[0]}
        LOCAL_IP=${CREATED_SERVER_PARAMS[1]}
        REMOTE_IP=${CREATED_SERVER_PARAMS[2]}
        PPTP_USER=${CREATED_SERVER_PARAMS[3]}
        PPTP_PASS=${CREATED_SERVER_PARAMS[4]}
        SERVER_IP=${CREATED_SERVER_PARAMS[5]}

        # when server from isn't contained in the EXISTED_SERVERS list
        if [[ ! " ${EXISTED_SERVERS[@]} " =~ " ${SERVER_NAME} " ]]; then
            echo "${SERVER_NAME} have to be created"
            # function create_server return ip of the created server
            SERVER_IP=$(create_server "${SERVER_NAME}")
            # add this ip_address to the and of server line
            setup_ansible
            run_ansible
            # add server's external IP address to file servers.txt
            CREATED_SERVER="${SERVER}   ${SERVER_IP}"
            sed -i -e "s/${SERVER}/${CREATED_SERVER}/" ${SERVER_LIST_FILE}
            ((COUNT_CREATED_SERVERS+=1))
            echo "server ${SERVER_NAME} (${SERVER_IP}) has been created"
            echo
        fi
    done

    # check if server from EXISTED_SERVERS contained in DESIRED_SERVERS
    for SERVER in "${EXISTED_SERVERS[@]}"
    do
        # convert string to array of server's params
        CREATED_SERVER_PARAMS=($(echo ${SERVER}))

        SERVER_NAME=${CREATED_SERVER_PARAMS[0]}

        # when server from isn't contained in the EXISTED_SERVERS list
        if [[ ! " ${DESIRED_SERVERS[@]} " =~ " ${SERVER_NAME} " ]] && [[ ${SERVER_NAME} != 'worker' ]]; then
            echo "${SERVER_NAME} have to be deleted"
            delete_server "${SERVER_NAME}"
            echo "server ${SERVER_NAME} is removed"
            ((COUNT_DELETED_SERVERS+=1))
        fi
    done

    echo "================================================"
    echo "$COUNT_CREATED_SERVERS servers has been created"
    echo "$COUNT_DELETED_SERVERS servers has been removed"
    echo
}

print_usage() {
    echo "usage: $0 [OPTION]"
    echo "Available options:"
    echo "  --server-list   path to file with servers that have to be created by this script"
    echo "  --help          display this help text and exit"
}

########################
#### SCRIPT STARTS  ####
########################

echo
echo "$(date)"
echo "Script has just started"
echo

if [ "$#" -eq 0 ]; then
    print_usage
    exit 0
fi

while [ "$1" != "" ]; do
    case "$1" in
        --server-list)
            if [ -f $2 ]; then
                main $2
            else
                echo "file with servers not found"
            fi
            exit
        ;;
        --help)
            print_usage
            exit
        ;;
        *)
            print_usage
            exit 1
        ;;
    esac
    shift
done
main