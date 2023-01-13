service {
    cluster-name poc
    node-id {{ node_id }}
    min-cluster-size 2
    proto-fd-max 15000
    migrate-fill-delay 0
    proto-fd-idle-ms 0
    disable-udf-execution true
}

logging {
    console {
        context any info
    }
}

network {
    service {
        address {{ ansible_ec2_local_ipv4 }}
        port 3000
    }

    heartbeat {
        mode mesh
        address {{ ansible_ec2_local_ipv4 }}
        port 3002
        %{ for ip in aerospike_ips ~}
        mesh-seed-address-port ${ip} 3002
        %{ endfor ~}
        interval 250
        timeout 10
    }

    fabric {
        address {{ ansible_ec2_local_ipv4 }}
        port 3001
    }
}

namespace test {
    rack-id {{ rack_id }}
    replication-factor 2
    memory-size 1G
    partition-tree-sprigs 8192
    default-ttl ${default_ttl}
    nsup-period 120
    storage-engine memory
}