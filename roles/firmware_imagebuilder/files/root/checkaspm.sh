#!/bin/sh

lspci -vv | awk '
/^[0-9a-fA-F]+:/ {
    if (dev) {
        print dev;
        if (lnkcap != "") print lnkcap;
        if (lnkctl != "") print lnkctl;
        print "----------------------";
    }
    dev = $0; lnkcap = ""; lnkctl = "";
}
/^\s+LnkCap:/ {
    match($0, /ASPM[^,;]*/);
    if (RSTART > 0) {
        lnkcap = "LnkCap: " substr($0, RSTART, RLENGTH);
    } else {
        lnkcap = "";
    }
}
/^\s+LnkCtl:/ {
    match($0, /ASPM[^,;]*/);
    if (RSTART > 0) {
        lnkctl = "LnkCtl: " substr($0, RSTART, RLENGTH);
    } else {
        lnkctl = "";
    }
}
END {
    if (dev) print dev "\n" lnkcap "\n" lnkctl "\n----------------------";
}
'
