#!/usr/bin/env bash
# Envoie un message SOAP au service Emprunt.
# Usage : ./envoyer.sh xml/01-emprunter.xml [soapAction]
#   ex.   ./envoyer.sh xml/10-emprunter-contractfirst.xml http://supnum.mr/bib/emprunterLivre
set -euo pipefail
fichier="${1:?fichier XML attendu}"
action="${2:-}"
curl -i -X POST http://localhost:8080/bib/EmpruntService \
  -H 'Content-Type: text/xml; charset=utf-8' \
  -H "SOAPAction: \"${action}\"" \
  --data-binary @"${fichier}"
echo
