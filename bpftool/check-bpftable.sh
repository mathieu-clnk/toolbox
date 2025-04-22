#!/bin/bash
for id in $(bpftool map show|awk -F':' '{print $1}')
do
  dirty_mapname=$(bpftool map show| grep -E "^$id" | awk -F'name ' '{print $2}' | awk -F' flags' '{print $1}')
  mapname=$(tr -dc '[[:print:]]' <<< "${dirty_mapname}")
  #if [[ $(echo $mapname | grep -c -E "cilium_lxc|cilium_tunnel_map|cilium_nat_v4|cilium_ipcache") -gt 0 ]]
  if [[ $(echo $mapname | grep -c -E "[[:alnum:]]") -gt 0 ]] && [[ $(bpftool map show|grep -c "name ${mapname}" ) -gt 0 ]]
  then
    echo "${mapname}"
    bpftool map dump id $id > $HOME/bpf/${mapname} 2>&1
  fi
done

for bpfmap in $(ls -C1 $HOME/bpf/)
do
  echo $bpfmap
  head $HOME/bpf/$bpfmap
done

bpftool map show|grep -E "cilium_lxc|cilium_tunnel_map|cilium_nat_v4|cilium_ipcache"

function itoa
{
#returns the dotted-decimal ascii form of an IP arg passed in integer format
echo -n $(($(($(($((${1}/256))/256))/256))%256)).
echo -n $(($(($((${1}/256))/256))%256)).
echo -n $(($((${1}/256))%256)).
echo $((${1}%256))
}

itoa 117440522