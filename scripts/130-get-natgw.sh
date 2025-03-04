#!/bin/bash
pref[0]="NatGateways"
ttft="aws_nat_gateway"

if [ "$1" != "" ]; then
    if [[ "$1" == "nat-"* ]]; then
        fn=$(printf "%s__%s.tf" $ttft $1)
        if [ -f "$fn" ]; then exit; fi
        cmd[0]="$AWS ec2 describe-nat-gateways --filter \"Name=state,Values=available\" \"Name=nat-gateway-id,Values=$1\""
    else
        cmd[0]="$AWS ec2 describe-nat-gateways --filter \"Name=state,Values=available\" \"Name=vpc-id,Values=$1\""
    fi
else
    cmd[0]="$AWS ec2 describe-nat-gateways --filter \"Name=state,Values=available\""
fi
c=0
cm=${cmd[$c]}

for c in $(seq 0 0); do

    cm=${cmd[$c]}
    #echo $cm
    awsout=$(eval $cm 2>/dev/null)
    if [ "$awsout" == "" ]; then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    count=$(echo $awsout | jq ".${pref[(${c})]} | length")
    if [ "$count" -gt "0" ]; then
        count=$(expr $count - 1)
        for i in $(seq 0 $count); do
            #echo $i
            cname=$(echo $awsout | jq ".${pref[(${c})]}[(${i})].NatGatewayId" | tr -d '"')
            #echo "$ttft $cname"
            eipall=$(echo $awsout | jq ".${pref[(${c})]}[(${i})].NatGatewayAddresses[0].AllocationId" | tr -d '"')
            #echo "eipall = $eipall"

            fn=$(printf "%s__%s.tf" $ttft $cname)
            if [ -f "$fn" ]; then
                echo "$fn exists already skipping"
                continue
            fi

            #echo "$ttft $cname $rname state get ..."
            ../../scripts/parallel_import3.sh $ttft ${cname} $cname
            #echo "$ttft $rname move"

            file=$(printf "%s-%s-1.txt" $ttft $cname)

            #printf "resource \"%s\" \"%s\" {}\n" $ttft $cname > $ttft.$cname.tf
            #terraform import $ttft.$cname "$cname" | grep Importing
            #terraform state show -no-color $ttft.$cname > t1.txt
            #rm -f $ttft.$cname.tf
            #file="t1.txt"

            subnets=()
            eipa=""
            echo $aws2tfmess >$fn
            while IFS= read line; do
                skip=0
                # display $line or do something with $line
                t1=$(echo "$line")
                if [[ ${t1} == *"="* ]]; then
                    tt1=$(echo "$line" | cut -f1 -d'=' | tr -d ' ')
                    tt2=$(echo "$line" | cut -f2- -d'=')
                    if [[ ${tt1} == "arn" ]]; then skip=1; fi
                    if [[ ${tt1} == "id" ]]; then skip=1; fi
                    if [[ ${tt1} == "role_arn" ]]; then skip=1; fi
                    if [[ ${tt1} == "owner_id" ]]; then skip=1; fi
                    if [[ ${tt1} == "association_id" ]]; then skip=1; fi

                    #if [[ ${tt1} == "public_dns" ]];then skip=1;fi
                    #if [[ ${tt1} == "private_dns" ]];then skip=1;fi
                    if [[ ${tt1} == "public_ip" ]]; then skip=1; fi
                    if [[ ${tt1} == "private_ip" ]]; then skip=1; fi
                    if [[ ${tt1} == "network_interface_id" ]]; then skip=1; fi
                    #if [[ ${tt1} == "default_network_acl_id" ]];then skip=1;fi
                    #if [[ ${tt1} == "ipv6_association_id" ]];then skip=1;fi
                    #if [[ ${tt1} == "ipv6_cidr_block" ]];then skip=1;fi
                    if [[ ${tt1} == "secondary_private_ip_address_count" ]]; then
                        sic=$(echo $tt2 | tr -d '"')
                        if [[ $sic == "0" ]]; then
                            skip=1
                        fi
                    fi
                    if [[ ${tt1} == "subnet_id" ]]; then
                        tt2=$(echo $tt2 | tr -d '"')
                        t1=$(printf "%s = aws_subnet.%s.id" $tt1 $tt2)
                        subnets+=$(printf "\"%s\" " $tt2)

                    fi
                    if [[ ${tt1} == "allocation_id" ]]; then
                        eipa=$(echo $tt2 | tr -d '"')
                        t1=$(printf "%s = aws_eip.%s.id" $tt1 $eipa)

                    fi

                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >>$fn
                fi

            done <"$file"
            ../../scripts/get-eip.sh $eipa
            for sub in ${subnets[@]}; do
                #echo "therole=$therole"
                sub1=$(echo $sub | tr -d '"')
                echo "calling for $sub1"
                if [ "$sub1" != "" ]; then
                    ../../scripts/105-get-subnet.sh $sub1
                fi
            done

        done

    fi
done
../../scripts/parallel_statemv.sh aws_nat_gateway

rm -f t*.txt
