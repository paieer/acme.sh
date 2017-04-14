#!/usr/bin/env sh

#
#CF_Key="sdfsdfsdfljlbjkljlkjsdfoiwje"
#
#CF_Email="xxxx@sss.com"

#DCP_user
#DCP_Api

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_dcp_add() {
  fulldomain=$1
  txtvalue=$2

  DCP_user="${DCP_user:-$(_readaccountconf_mutable DCP_user)}"
  DCP_Api="${DCP_Api:-$(_readaccountconf_mutable DCP_Api)}"
  if [ -z "$DCP_user" ] || [ -z "$DCP_Api" ]; then
    DCP_user=""
    DCP_Api=""
    _err "You don't specify cloudflare api key and email yet."
    _err "Please create you key and try again."
    return 1
  fi

  #save the api key and email to the account conf file.
  _saveaccountconf_mutable DCP_user "$DCP_user"
  _saveaccountconf_mutable DCP_Api "$DCP_Api"

  _debug "First detect the root zone"
    if ! _get_root "$fulldomain"; then
      _err "invalid domain"
      return 1
    fi
  _debug _domain_url "$_domain_url"
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _debug "Getting txt records"

  _dcp_post $_sub_domain $_domain_url $txtvalue
  _debug response $response
}

#fulldomain txtvalue
dns_dcp_rm() {
  fulldomain=$1
  txtvalue=$2
  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _domain_url "$_domain_url"
  _debug _sub_domain "$_sub_domain"
  _debug _sub_domain_url "$_sub_domain_url"
  _debug _domain "$_domain"

  _debug "DELETE txt records"
  _dcp_del $_sub_domain_url

}

_get_root() {
  domain=$1
  i=2
  p=1
  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f $i-100)
    _debug h "$h"
    if [ -z "$h" ]; then
      #not valid
      return 1
    fi

    if ! _dcp_get MAIN_DOMAIN $h "$DCP_Api.json" URL; then
      return 1
    fi

    _debug response $response

    if _contains "$response" "domains" >/dev/null; then
      _domain=$h
      _domain_url=$response

      _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-$p)
      _dcp_get SUB_DOMAIN $_sub_domain $_domain_url URL
      _sub_domain_url=$response
      return 0
    fi
    p=$i
    i=$(_math "$i" + 1)
  done
  return 1
}

_dcp_get() {
  m=$1
  ep=$2
  url=$3
  data=$4

  if [ "$data" == "URL" ]; then
    if [ "$m" == "MAIN_DOMAIN" ]; then
        response=`curl -s -X GET -u $DCP_user -k $url |jq '.results[]|select(.zone_name == "'$ep'").url'|sed -e 's/"//g'`
    else
        response=`curl -s -X GET -u $DCP_user -k $url |jq '.[]|select(.host == "'$ep'").url'|sed -e 's/"//g'`
    fi
  else
    response=`curl -s -X GET -u $DCP_user -k $url |jq '.[]|select(.host == "'$ep'")|select(.type == \"TXT\").data'|sed -e 's/"//g'`
  fi

  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  return 0
}

_dcp_post() {
  sub_domain=$1
  url="$2"
  data=$3

  data='[{"type":"TXT","host":"'$sub_domain'","data":"'$data'","ttl":"60"}]'
  response=`curl -s -X POST -u $DCP_user -H "Content-Type:application/json" -k $url -d $data`
  _debug data $data
  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
_dcp_del() {
  url="$1"

  response=`curl -s -X DELETE -u $DCP_user -k $url`
  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
