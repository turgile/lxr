#!/bin/bash
# $Id: initial-config.sh,v 1.1 2012/01/23 08:55:02 ajlittoz Exp $

CSI=$'\x1b[';	# CSI = esc [
VTbold="${CSI}1m";
VTnorm="${CSI}0m";
VTred="${VTbold}${CSI}31m";
VTyellow="${VTbold}${CSI}33m";
VTgreen="${VTbold}${CSI}32m";

echo "${VTyellow}***${VTnorm} Initial phase configurator for LXR (\$Revision: 1.1 $) ${VTyellow}***${VTnorm}"
echo

while : ; do
	read -p "Configure for single/multiple trees? [S/m] " cardinality
	if [[ "$cardinality" ]] ; then
		case "$cardinality" in
			"s" | "S" )
				cardinality="s"
				break
			;;
			"m" | "M" )
				cardinality="m"
				break
			;;
			* )
				echo "ERROR: invalid response, try again"
				continue
			;;
		esac
	else
		cardinality="s"
		break
	fi
done

lxr_root=`pwd`
echo
echo "Your LXR root directory is: ${VTbold}$lxr_root${VTnorm}"
echo
# Escape the path separator (also regexp delimitor)
lxr_root="${lxr_root//\//\\/}"

confdir="lxrconf.d"

# chmod -R a=r templates
echo "templates directory now protected read-only"

cp templates/Apache/htaccess-generic .htaccess
echo "File ${VTbold}.htaccess${VTnorm} written in your LXR root directory"
echo "--- List its content with 'more .htacess'"

sed -e "s/%LXRroot%/$lxr_root/g" templates/Apache/apache2-require.pl > $confdir/apache2-require.pl
echo "File ${VTbold}apache2-require.pl${VTnorm} written in $confdir directory"

sed -e "s/%LXRroot%/$lxr_root/g" templates/Apache/lxrserver.conf \
	| sed -e "s/#=$cardinality=//" > $confdir/lxrserver.conf
echo "File ${VTbold}lxrserver.conf${VTnorm} written in $confdir directory"

# lxr.conf pre-configuration

lc="$confdir/lxr.conf"		# lxr.conf destination
cp templates/lxr.conf $lc
sed -e "s/%LXRroot%/$lxr_root/g" -i $lc

glimpse=`which glimpse 2>/dev/null`
if [[ "$glimpse" ]] ; then	# glimpse exists
	glimpse="${glimpse//\//\\/}"
	sed -e "s/%glimpse%/$glimpse/" -i $lc
	glimpseindex=`which glimpseindex`
	if [[ "$glimpseindex" ]] ; then
		glimpseindex="${glimpseindex//\//\\/}"
		sed -e "s/%glimpseindex%/$glimpseindex/" -i $lc
	else
		echo "${VTred}***Error:${VTnorm} glimpseindex not installed with glimpse!"
	fi
else						# no glimpse
	sed -e "/%glimpse%/s/^/#/" -i $lc
	sed -e "/%glimpseindex%/s/^/#/" -i $lc
fi

swish=`which swish-e 2>/dev/null`
if [[ "$swhish" ]] ; then		# swish-e exists
	swish="${swish//\//\\/}"
	sed -e "s/%swish%/$swish/" -i $lc
else						# no swhish-e
	sed -e '/%swish%/s/^/#/' -i $lc
fi

if [[ (-z "$glimpse") && (-z "$swish") ]] ; then
	echo "${VTred}***Error:${VTnorm} neither glimpse nor swish-e installed!"
fi

if [[ "$glimpse" && "$swish" ]] ; then
	echo "${VTred}***Error:${VTnorm} both glimpse and swish-e installed!"
	echo "*** Manually edit lxr.conf to comment out one of them ***"
fi

ctagsbin=`which ctags`
if [[ "$ctagsbin" ]] ; then		# ctags exists
	ctagsbin="${ctagsbin//\//\\/}"
	sed -e "s/%ctags%/$ctagsbin/" -i $lc
else						# no swhish-e
	echo "${VTred}***Error:${VTnorm} ctags not installed!"
fi

echo "Prototype ${VTbold}lxr.conf${VTnorm} written in $confdir directory"

echo
echo "${VTyellow}***${VTnorm} Configuration directory $confdir now contains: ${VTyellow}***${VTnorm}"
ls -al $confdir
