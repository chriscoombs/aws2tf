usage(){
	echo "Usage: $0 [-p <profile>] [-c] [-v] [-r <region>] [-t <type>] [-h] [-d]"
  echo "       -p <profile> specify the AWS profile to use (Default=\"default\")"
  echo "       -c           continue from previous run (Default=\"no\")"
  echo "       -r <region>  specify the AWS region to use (Default=the aws command line setting)"
  echo "       -v           stop after terraform validate step"
  echo "       -h           Help - this message"
  echo "       -d           Debug - lots of output"
  echo "       -s <stack name>  Traverse a Stack and import resources (experimental)"
  echo "       -t <type>    choose a sub-type of AWS resources to get" 
   echo "           iam"                
   echo "           org" 
   echo "           code"
   echo "           appmesh" 
   echo "           kms"
   echo "           lambda" 
   echo "           rds" 
   echo "           ecs"
   echo "           eks"
   echo "           emr"
   echo "           secrets" 
   echo "           lf" 
   echo "           athena" 
   echo "           glue" 
   echo "           params"
   echo "           sagemaker" 
   echo "           eb"
   echo "           ec2"
   echo "           s3"
   echo "           s3"
   echo "           spot"
   echo "           tgw"
   echo "           vpc"
	exit 1
}



x="no"
p="default" # profile
f="no"
v="no"
r="no" # region
c="no" # combine mode
d="no"
s="no"

while getopts ":p:r:x:f:v:t:i:c:d:h:s:" o; do
    case "${o}" in
        h) usage
        ;;
        i) i=${OPTARG}
        ;;
        t) t=${OPTARG}
        ;;
        r) r=${OPTARG}
        ;;
        x) x="yes"
        ;;
        p) p=${OPTARG}
        ;;
        f) f="yes"
        ;;
        v) v="yes"
        ;;
        c) c="yes"
        ;;
        d) d="yes"
        ;;
        s) s=${OPTARG}
        ;;
        
        *)
            usage
        ;;
    esac
done
shift $((OPTIND-1))

trap ctrl_c INT

function ctrl_c() {
        echo "Requested to stop."
        exit 1
}

if [ "$d" = "yes" ]; then
    set -x
fi

export aws2tfmess="# File generated by aws2tf see https://github.com/aws-samples/aws2tf"

if [ -z ${AWS_ACCESS_KEY_ID+x} ] && [ -z ${AWS_SECRET_ACCESS_KEY+x} ];then
    mysub=`aws sts get-caller-identity --profile $p | jq .Account | tr -d '"'`
else
    mysub=`aws sts get-caller-identity | jq .Account | tr -d '"'`
fi
if [ "$r" = "no" ]; then
echo "Region not specified - Getting region from aws cli ="
r=`aws configure get region`
echo $r
fi
if [ "$mysub" == "null" ] || [ "$mysub" == "" ]; then
    echo "Account is null exiting"
    exit
fi



#s=`echo $mysub`
mkdir -p  generated/tf.$mysub
cd generated/tf.$mysub


if [ "$f" = "no" ]; then
    if [ "$c" = "no" ]; then
        echo "Cleaning generated/tf.$mysub"
        rm -f *.txt *.sh *.log *.sav *.zip
        rm -f *.tf *.json *.tmp 
        rm -f terraform.* tfplan 
        rm -rf .terraform data aws_*
    fi
else
    sort -u data/processed.txt > data/pt.txt
    cp pt.txt data/processed.txt
fi

mkdir -p data

rm -f import.log
#if [ "$f" = "no" ]; then
#    ../../scripts/resources.sh 2>&1 | tee -a import.log
#fi

if [ ! -z ${AWS_DEFAULT_REGION+x} ];then
    r=`echo $AWS_DEFAULT_REGION`
    echo "region $AWS_DEFAULT_REGION set from env variables"
fi

if [ ! -z ${AWS_PROFILE+x} ];then
    p=`echo $AWS_PROFILE`
    echo "profile $AWS_PROFILE set from env variables"
fi

export AWS="aws --profile $p --region $r --output json "
echo " "
echo "Account ID = ${mysub}"
echo "Region = ${r}"
echo "AWS Profile = ${p}"
echo "Extract KMS Secrets to .tf files (insecure) = ${x}"
echo "Fast Forward = ${f}"
echo "Verify only = ${v}"
echo "Type filter = ${t}"
echo "Combine = ${c}"
echo "AWS command = ${AWS}"
echo " "


# cleanup from any previous runs
#rm -f terraform*.backup
#rm -f terraform.tfstate
#rm -f tf*.sh


# write the aws.tf file
printf "terraform { \n" > aws.tf
printf "required_version = \"~> 1.1.0\"\n" >> aws.tf
printf "  required_providers {\n" >> aws.tf
printf "   aws = {\n" >> aws.tf
printf "     source  = \"hashicorp/aws\"\n" >> aws.tf
printf "      version = \"= 3.69.0\"\n" >> aws.tf
printf "    }\n" >> aws.tf
printf "  }\n" >> aws.tf
printf "}\n" >> aws.tf
printf "\n" >> aws.tf
printf "provider \"aws\" {\n" >> aws.tf
printf " region = \"%s\" \n" $r >> aws.tf
if [ -z ${AWS_ACCESS_KEY_ID+x} ] && [ -z ${AWS_SECRET_ACCESS_KEY+x} ];then
    printf " shared_credentials_file = \"~/.aws/credentials\" \n"  >> aws.tf
    printf " profile = \"%s\" \n" $p >> aws.tf
    export AWS="aws --profile $p --region $r --output json "
else
    export AWS="aws --region $r --output json "
fi
printf "}\n" >> aws.tf

cat aws.tf
cp ../../stubs/data-aws.tf .

if [ "$t" == "no" ]; then t="*"; fi

pre="*"
if [ "$t" == "vpc" ]; then
pre="1*"
t="*"
if [ "$i" == "no" ]; then
    echo "VPC Id null exiting - specify with -i <vpc-id>"
    exit
fi
fi

if [ "$t" == "tgw" ]; then
pre="type"
t="transitgw"
if [ "$i" == "no" ]; then
    echo "TGW Id null exiting - specify with -i <tgw-id>"
    exiting
fi
fi


if [ "$t" == "ecs" ]; then
pre="3*"
if [ "$i" == "no" ]; then
    echo "Cluster Name null exiting - specify with -i <cluster-name>"
    exit
fi
fi


if [ "$t" == "eks" ]; then
pre="30*"
if [ "$i" == "no" ]; then
    echo "Cluster Name null exiting - specify with -i <cluster-name>"
    exit
fi
fi

if [ "$t" == "org" ]; then pre="01*"; fi
if [ "$t" == "code" ]; then pre="62*"; fi
if [ "$t" == "appmesh" ]; then pre="360*"; fi
if [ "$t" == "kms" ]; then pre="08*"; fi
if [ "$t" == "lambda" ]; then pre="700*"; fi
if [ "$t" == "rds" ]; then pre="60*"; fi
if [ "$t" == "emr" ]; then pre="37*"; fi
if [ "$t" == "secrets" ]; then pre="45*"; fi
if [ "$t" == "lf" ]; then pre="63*"; fi
if [ "$t" == "athena" ]; then pre="66*"; fi
if [ "$t" == "glue" ]; then pre="65*"; fi
if [ "$t" == "sagemaker" ]; then pre="68*"; fi
if [ "$t" == "eb" ]; then pre="71*"; fi
if [ "$t" == "ec2" ]; then pre="25*"; fi
if [ "$t" == "s3" ]; then pre="06*"; fi
if [ "$t" == "sc" ]; then pre="81*"; fi
if [ "$t" == "spot" ]; then pre="25*"; fi
if [ "$t" == "params" ]; then pre="445*"; fi
if [ "$t" == "artifact" ]; then pre="627*"; fi

exclude="iam"

if [ "$t" == "iam" ]; then pre="05*" && exclude="xxxxxxx"; fi

if [ "$c" == "no" ]; then
    echo "terraform init -upgrade"
    terraform init -upgrade -no-color 2>&1 | tee -a import.log
fi
pwd
ls
#############################################################################
date
lc=0
if [[ "$s" == "no" ]];then 
echo "t=$t"
echo "loop through providers"
tstart=`date +%s`
for com in `ls ../../scripts/$pre-get-*$t*.sh | cut -d'/' -f4 | sort -g`; do    
    start=`date +%s`
    echo "$com" 
    if [[ "$com" == *"${exclude}"* ]]; then
        echo "skipping $com"
    else
        docomm=". ../../scripts/$com $i"
        if [ "$f" = "no" ]; then
            eval $docomm 2>&1 | tee -a import.log
        else
            grep "$docomm" data/processed.txt
            if [ $? -eq 0 ]; then
                echo "skipping $docomm"
            else
                eval $docomm 2>&1 | tee -a import.log
            fi
        fi
        lc=`expr $lc + 1`

        file="import.log"
        while IFS= read -r line
        do
            if [[ "${line}" == *"Error"* ]];then
          
                if [[ "${line}" == *"Duplicate"* ]];then
                    echo "Ignoring $line"
                else
                    echo "Found Error: $line exiting .... (pass for now)"
                    
                fi
            fi

        done <"$file"

        echo "$docomm" >> data/processed.txt
        terraform validate -no-color
        end=`date +%s`
        runtime=$((end-start))
        echo "$com runtime $runtime seconds"
    fi
    
done
else
    echo "Stack set $s traverse - experimental"
    ../../scripts/get-stack.sh $s
    chmod 755 commands.sh
    #if [ "$v" = "yes" ]; then
    #    exit
    #fi
    ./commands.sh
fi

#########################################################################
tend=`date +%s`
truntime=$((tend-tstart))
echo "Total runtime in seconds $truntime"

date

echo "terraform fmt > /dev/null ..."
terraform fmt > /dev/null
echo "Terraform validate ..."
terraform validate -no-color


if [ "$v" = "yes" ]; then
    exit
fi

echo "Terraform Refresh ..."
terraform refresh  -no-color
echo "Terraform Plan ..."
terraform plan -no-color

echo "---------------------------------------------------------------------------"
echo "aws2tf output files are in generated/tf.$mysub"
echo "---------------------------------------------------------------------------"

if [ "$t" == "eks" ]; then
echo "aws eks update-kubeconfig --name $i"
fi