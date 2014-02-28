#!/bin/sh

Usage() {
	cat <<EOF
${0##*/} [-c] instance-type

print ephemeral store block-device-mapping arguments for 'instance-type'
If '-c' given, also print "--instance-type <instance-type>"

examples:
 * ${0##*/} m1.large
   --block-device-mapping=sdb=ephemeral0 --block-device-mapping=sdc=ephemeral1
 * ec2-run-instances \$(${0##*/} -c m1.xlarge) --key mykey ami-c692ec94
   is the same as running:
   ec2-run-instances --block-device-mapping=sdb=ephemeral0 \\
      --block-device-mapping=sdc=ephemeral1 --instance-type=m1.large \\
      --key mykey ami-c692ec94
EOF
}

[ "$1" = "-h" -o "$1" = "--help" ] && { Usage; exit 0; }
print_type=0
[ "$1" = "-c" ] && { print_type=1; shift; }
[ $# -eq 1 ] || { Usage 1>&2; exit 1; }
itype=${1}

# data cleaned from from http://aws.amazon.com/ec2/instance-types/
# t1.micro     NONE    # m2.2xlarge    850   # c1.xlarge    1690
# m1.small      160    # m1.large      850   # m1.xlarge    1690
# c1.medium     350    # cc1.4xlarge  1690   # cc1.4xlarge  1690
# m2.xlarge     420    # m2.4xlarge   1690   # cg1.4xlarge  1690
bdmaps=""
ba="--block-device-mapping="
case "${itype}" in
	t1.micro) bdmaps="";; # there is no ephemeral store on t1.micro
	m1.small|c1.medium)
		bdmaps="";; # the first on i386 always attached. sda2=ephemeral0
	m2.xlarge) bdmaps="";; # one 420 for m2.xlarge
	m1.large|m2.2xlarge|cg1.*|cc1.*)
		bdmaps="${ba}sdb=ephemeral0 ${ba}sdc=ephemeral1";;
	m1.xlarge|m2.4xlarge|c1.xlarge)
		bdmaps="${ba}sdb=ephemeral0 ${ba}sdc=ephemeral1"
		bdmaps="${bdmaps} ${ba}sdd=ephemeral2 ${ba}sde=ephemeral3";;
	*) echo "unknown instance type $itype" 1>&2; exit 1;;
esac
[ ${print_type} -eq 0 ] && echo "${bdmaps}" ||
	echo "${bdmaps} --instance-type=${itype}"
exit 0
# vi: ts=4 noexpandtab
