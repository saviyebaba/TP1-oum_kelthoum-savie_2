# TP1 — SOAP et WSDL · Réponses

**Binôme :** Nom1 — Nom2  
**Environnement :** JDK 17, Maven, Metro (jaxws-rt 4.0.2), SoapUI, curl

Les messages envoyés sont dans `xml/`. Le script `envoyer.sh` reprend la commande curl de l'énoncé :

```bash
./envoyer.sh xml/01-emprunter.xml                                         # SOAPAction ""
./envoyer.sh xml/10-emprunter-contractfirst.xml http://supnum.mr/bib/emprunterLivre
```

| Fichier | Usage |
|---|---|
| `01-emprunter.xml` | Étape 3.1 — emprunt valide (SOAP 1.1) |
| `02-emprunter-12.xml` | Étape 3.3 — même message, enveloppe SOAP 1.2 |
| `03-fault-sender-12.xml` | Étape 4.5 — Fault SOAP 1.2 écrite à la main |
| `04-rendre-errone.xml` / `05-rendre-corrige.xml` | Étape 3.4 — message aux cinq erreurs, puis corrigé |
| `06` à `09` | Étape 4 — ISBN invalide, livre indisponible, `mustUnderstand` 1 et 0, numéro d'emprunt invalide |
| `10` à `12` | Partie B — paramètres qualifiés : emprunt valide, livre indisponible, ISBN invalide |

---

## Partie A — Code-first

### Étape 1 — Créer et lancer le service

**1. Annotations.**
`@WebService` (`jakarta.jws.WebService`) fait de `EmpruntService` un service web. JAX-WS publie alors ses méthodes publiques comme opérations ; `@WebMethod`, `@WebParam` et `@WebResult` ne font qu'en préciser les noms.
`@WebFault` (`jakarta.xml.ws.WebFault`) fait de `LivreIndisponibleException` une erreur déclarée dans le contrat. Elle produit un `wsdl:fault` sur l'opération et un élément XSD `LivreIndisponible` construit à partir du bean retourné par `getFaultInfo()`.

**2. Constructeur vide.**
Les classes `Emprunt` et `LivreIndisponibleInfo` sont converties entre Java et XML par JAXB. Pour désérialiser un message, JAXB instancie d'abord l'objet par réflexion avec le constructeur sans argument, puis remplit les champs un par un à mesure qu'il lit le XML. Sans constructeur vide, JAXB refuse la classe dès la publication (erreur du type *« does not have a no-arg default constructor »*) et aucun WSDL n'est généré.

### Étape 2 — Lire le WSDL généré

**1. URL et opérations.**
URL du service (`service › port › soap:address`) : `http://localhost:8080/bib/EmpruntService`.

| Opération | Message d'entrée (élément) | Message de sortie (élément) | Fault |
|---|---|---|---|
| `emprunterLivre` | `emprunterLivre` (`tns:emprunterLivre`) | `emprunterLivreResponse` (`tns:emprunterLivreResponse`) | `LivreIndisponibleException` (`tns:LivreIndisponible`) |
| `rendreLivre` | `rendreLivre` (`tns:rendreLivre`) | `rendreLivreResponse` (`tns:rendreLivreResponse`) | — |

Les autres éléments du WSDL généré sont nommés d'après le code :
- le `portType` s'appelle `EmpruntService`, comme la classe ;
- le `binding` s'appelle `EmpruntPortBinding`, d'après le `portName` ;
- chaque message a une seule part `parameters`. C'est le style *document/literal wrapped*.

**2. Style, use, version.**
`<soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>` et `<soap:body use="literal"/>` : le binding est **document / literal** (wrapped).
Le préfixe `soap` est lié à `http://schemas.xmlsoap.org/wsdl/soap/`, l'extension WSDL de **SOAP 1.1**. Pour SOAP 1.2, ce serait `http://schemas.xmlsoap.org/wsdl/soap12/`. Le `soapAction` déclaré est vide (`""`).

**3. Types XSD (`?xsd=1`).**
- `isbn` → `xs:string`, `minOccurs="0"`.
- `dateRetour` → `xs:string`, `minOccurs="0"`, car c'est un `String` en Java.
- `penalite` → `xs:decimal`, à partir du `BigDecimal`.

La règle de format de l'ISBN **n'apparaît pas**. Le motif `97[89]-…` ne vit que dans le code Java (`Pattern ISBN`), où JAXB ne le voit pas. Un client qui lit le contrat ne peut pas savoir quels ISBN sont acceptés.

**4. Préfixes dans la requête SoapUI.**
Non. Seul l'élément enveloppe porte le préfixe (`<bib:emprunterLivre>`). Ses enfants `<idAdherent>` et `<isbn>` n'en ont pas. Le schéma généré ne déclare pas `elementFormDefault`, qui vaut donc `unqualified` : les éléments locaux n'appartiennent à aucun espace de noms.

```xml
<bib:emprunterLivre>
   <idAdherent>A-117</idAdherent>
   <isbn>978-1-234-5678-9</isbn>
</bib:emprunterLivre>
```

**5. Onglet Raw : HTTP, XML, SOAP, WSDL.**
- **HTTP** : la ligne `POST /bib/EmpruntService HTTP/1.1` et les en-têtes (`Host`, `Content-Type: text/xml;charset=UTF-8`, `SOAPAction: ""`, `Content-Length`). HTTP n'est que le **transport** : il achemine le message jusqu'à l'URL.
- **XML** : tout le corps de la requête. XML est le **format de données** : balises, espaces de noms, encodage.
- **SOAP** : la structure `Envelope / Header / Body` dans ce XML. SOAP est le **protocole de messagerie**. Il fixe le format de l'enveloppe, les en-têtes extensibles (`mustUnderstand`), les Faults et le modèle de traitement.
- **WSDL** : il n'apparaît **pas** dans le message. C'est le **contrat** lu avant l'appel : il décrit quelles opérations existent (`portType`), quelles données circulent (`message` / `types` XSD), comment les emballer (`binding`) et où envoyer (`service`). SoapUI l'a utilisé pour fabriquer la requête.

### Étape 3 — Envoyer des messages SOAP

`xml/01-emprunter.xml` reçoit `HTTP/1.1 200 OK` :

```xml
<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
  <S:Body>
    <ns2:emprunterLivreResponse xmlns:ns2="http://supnum.mr/bib">
      <emprunt>
        <numero>E-2026-0813</numero>
        <dateRetour>2026-12-08</dateRetour>
      </emprunt>
    </ns2:emprunterLivreResponse>
  </S:Body>
</S:Envelope>
```

Le numéro vaut `0813` parce que la requête SoapUI de l'étape 2 a déjà pris `0812`. La date est celle du jour plus 14 jours. Si on renvoie le même fichier une deuxième fois, le livre est désormais sorti et l'appel renvoie la Fault `LivreIndisponible`.

**1. Pourquoi POST, même pour lire ?**
La liaison SOAP 1.1/HTTP n'utilise que `POST`. La requête est une enveloppe XML qui doit voyager dans le **corps** HTTP, or `GET` n'a pas de corps. Par ailleurs, toutes les opérations partagent **une seule URL** : l'opération est désignée par l'élément du `Body` (et le `SOAPAction`), pas par la méthode HTTP. HTTP sert de tuyau et la sémantique est dans l'enveloppe. Conséquence : aucune mise en cache HTTP, même pour une lecture.

**2. Le bloc `jeton` a-t-il bloqué le traitement ?**
Non, la réponse est normale. Le bloc n'a pas `mustUnderstand="1"`. Le modèle de traitement SOAP autorise alors le destinataire à **ignorer** un en-tête qu'il ne comprend pas, et aucun handler du service ne traite `jeton`.

**3. Message SOAP 1.2.**
Le service répond par une Fault **SOAP 1.1** avec `HTTP 500` :

```xml
<faultcode>S:VersionMismatch</faultcode>
<faultstring>Couldn't create SOAP message. Expecting Envelope in namespace
  http://schemas.xmlsoap.org/soap/envelope/, but got http://www.w3.org/2003/05/soap-envelope</faultstring>
```

D'après l'étape 2, le binding est SOAP 1.1 : l'endpoint attend une enveloppe dans l'espace de noms `http://schemas.xmlsoap.org/soap/envelope/`. Une enveloppe dans un autre espace de noms est une autre version du protocole. La spécification prévoit alors le code `VersionMismatch`, qui s'exprime dans la version que le service comprend, ici 1.1.

**4. Les cinq erreurs du message `rendreLivre`.**

| # | Erreur | Correction | Effet côté serveur |
|---|---|---|---|
| 1 | `<soap:envelope>` en minuscule ; ne correspond pas à `</soap:Envelope>` | `<soap:Envelope>` | Fault : *unexpected XML tag. expected `{…/envelope/}Envelope` but found `{…}envelope`* ; XML mal formé |
| 2 | Espace de noms `http://supnum.mr/bibliotheque` | `http://supnum.mr/bib` | Fault : *Cannot find dispatch method for `{http://supnum.mr/bibliotheque}rendreLivre`* |
| 3 | `</rendreLivre>` sans préfixe ; ne ferme pas `<bib:rendreLivre>` | `</bib:rendreLivre>` | XML mal formé, Fault d'analyse |
| 4 | Paramètre `<bib:numero>` | `<numeroEmprunt>`, nom du `@WebParam`, sans préfixe car `unqualified` | **Aucune erreur** |
| 5 | `Header` placé **après** le `Body` | `Header` avant `Body`, premier enfant de l'enveloppe | **Aucune erreur** |

Version corrigée : `xml/05-rendre-corrige.xml`. Elle renvoie `<penalite>0</penalite>`.

Deux erreurs passent sans erreur, et c'est la leçon de cette étape :
- **Erreur 4.** JAXB ignore les éléments inconnus quand il désérialise le wrapper. `numeroEmprunt` reçoit donc `null`, et la version de l'étape 3 renvoie quand même une pénalité de 0. C'est un échec **silencieux** : le client croit avoir rendu le livre E-2026-0812. Seule l'étape 4 transforme ce cas en Fault (*Numéro d'emprunt inconnu : null*).
- **Erreur 5.** Metro lit l'enveloppe en flux et ne regarde pas ce qui suit le `Body`. Le bloc placé après n'est pas lu comme en-tête : le jeton est perdu sans bruit. Il n'a pas `mustUnderstand`, donc rien ne réclame son traitement.

Metro ne valide pas les messages contre le schéma par défaut. Seules les erreurs de **bonne formation** XML et d'**aiguillage** (QName inconnu) sont détectées. Les erreurs de **contenu** passent.

### Étape 4 — Provoquer et construire des Faults

**1. Cas 1 et 2.**

| Cas | Fichier | HTTP | `faultcode` | `faultstring` |
|---|---|---|---|---|
| ISBN `978-2-10` | `06-isbn-invalide.xml` | 500 | `S:Client` | `ISBN mal formé : 978-2-10` |
| ISBN `978-2-10-074444-4` | `07-livre-indisponible.xml` | 500 | `S:Server` | `Livre indisponible` |

En SOAP 1.1 sur HTTP, toute Fault revient avec `500 Internal Server Error`, quel que soit le fautif.

**2. Contenu de `<detail>` (cas 2).**

```xml
<detail>
  <ns2:LivreIndisponible xmlns:ns2="http://supnum.mr/bib">
    <isbn>978-2-10-074444-4</isbn>
    <retourPrevu>2026-12-02</retourPrevu>
  </ns2:LivreIndisponible>
</detail>
```

C'est le `faultInfo` (`LivreIndisponibleInfo`) sérialisé. Sa structure se suit dans le WSDL en quatre maillons :
1. `portType › operation emprunterLivre › wsdl:fault` ;
2. le message `LivreIndisponibleException` ;
3. sa part `fault`, avec `element="tns:LivreIndisponible"` ;
4. dans le XSD `?xsd=1`, l'élément `LivreIndisponible` de type `livreIndisponibleInfo` (`isbn`, `retourPrevu`).

Le cas 1 n'a pas de `<detail>` : la `SOAPFaultException` est construite à la main, sans détail, et n'est pas déclarée dans le contrat.

**3. Code choisi pour le livre indisponible.**
JAX-WS a choisi **`Server`**. Il mappe toute exception applicative déclarée (`@WebFault`) sur `Server`, sans distinguer le fautif.

Ce n'est pas vraiment une erreur du serveur, qui fonctionne normalement : c'est une **erreur métier**. Ce n'est pas non plus une erreur du client, dont la requête est bien formée et valide.

Notre choix : **garder `Server`** (`Receiver` en 1.2), mais pour la bonne raison. SOAP définit `Client` comme « ne pas renvoyer ce message sans le modifier ». `Server` signifie « le problème ne tient pas au contenu du message, le même message pourra réussir plus tard ». Ici, la même requête réussira une fois le livre rendu le 02/12. Le `<detail>` typé `LivreIndisponible`, avec `retourPrevu`, indique au client qu'il s'agit d'un cas métier et non d'une panne. En SOAP 1.2, on le préciserait avec un `Subcode` comme `bib:LivreIndisponible`.

L'ISBN mal formé, au contraire, est bien une faute `Client` : renvoyer ce message ne marchera jamais.

**4. `mustUnderstand`.**
- `mustUnderstand="1"` (`08-mustunderstand-1.xml`) : l'opération **n'est pas exécutée**. Le serveur répond par une Fault avant tout traitement, avec `faultcode S:MustUnderstand` et `faultstring MustUnderstand headers:[{http://supnum.mr/bib}jeton] are not understood` (HTTP 500). L'émetteur exige que l'en-tête soit traité, et aucun composant du service ne sait le traiter. Le serveur ne peut donc pas l'ignorer et doit tout refuser.
- `mustUnderstand="0"` (`08-mustunderstand-0.xml`) : même comportement que sans l'attribut. L'en-tête est facultatif, il est ignoré et la réponse est normale.

**Étape 4.4.** Avec le contrôle ajouté dans `rendreLivre`, `09-rendre-numero-invalide.xml` (`X-1999-0001`) renvoie `S:Client` / `Numéro d'emprunt inconnu : X-1999-0001`. Le message de l'erreur 4 de l'étape 3 (`<bib:numero>`) donne maintenant `Numéro d'emprunt inconnu : null` au lieu d'un faux succès.

**Étape 4.5.** Voir `xml/03-fault-sender-12.xml`. `xmllint --noout xml/03-fault-sender-12.xml` ne renvoie aucune erreur.

**5. Fault 1.2 et Faults 1.1 reçues.**

| | SOAP 1.1 (reçues) | SOAP 1.2 (écrite) |
|---|---|---|
| Espace de noms | `http://schemas.xmlsoap.org/soap/envelope/` | `http://www.w3.org/2003/05/soap-envelope` |
| Fautif | `<faultcode>` plat : `Client` / `Server` | `<soap:Code><soap:Value>` : `Sender` / `Receiver`, avec `Subcode` imbriquables pour préciser |
| Explication | `<faultstring>`, une seule langue | `<soap:Reason>` avec un ou plusieurs `<soap:Text xml:lang="…">` |
| Détail | `<detail>`, sans espace de noms | `<soap:Detail>`, qualifié comme tous les enfants de `Fault` |
| Acteurs | `faultactor` | `soap:Node` et `soap:Role` |
| HTTP | toujours 500 | 400 pour `Sender`, 500 pour `Receiver` ; `Content-Type: application/soap+xml` |

---

## Partie B — Contract-first

### Étape 5 — Générer le code depuis le WSDL

**1. Opération, fault, action.**
- Opération : `emprunterLivre` dans le `portType EmpruntPortType`.
- Message de fault : `bib:LivreIndisponibleFault`, dont la part `fault` est l'élément `bib:LivreIndisponible`. Il est référencé par `<wsdl:fault name="LivreIndisponible">`.
- Action SOAP à envoyer : `http://supnum.mr/bib/emprunterLivre`, via `<soap:operation soapAction="…"/>` dans le binding.

**2. Signature dans `EmpruntPortType`.**

```java
@WebMethod(action = "http://supnum.mr/bib/emprunterLivre")
@WebResult(name = "emprunt", targetNamespace = "http://supnum.mr/bib")
@RequestWrapper(localName = "emprunterLivre", targetNamespace = "http://supnum.mr/bib",
                className = "mr.supnum.bib.contrat.EmprunterLivre")
@ResponseWrapper(localName = "emprunterLivreResponse", targetNamespace = "http://supnum.mr/bib",
                 className = "mr.supnum.bib.contrat.EmprunterLivreResponse")
public EmpruntType emprunterLivre(
        @WebParam(name = "idAdherent", targetNamespace = "http://supnum.mr/bib") String idAdherent,
        @WebParam(name = "isbn", targetNamespace = "http://supnum.mr/bib") String isbn)
    throws LivreIndisponibleFault;
```

wsimport reconnaît le style *wrapped* : l'élément d'entrée porte le nom de l'opération, et chaque message a une seule part `parameters`. Il « déplie » donc les enfants du wrapper en paramètres Java. `IsbnType` devient un simple `String` : une restriction par motif n'a pas d'équivalent en Java.

**3. Type Java de `dateRetour`.**
`javax.xml.datatype.XMLGregorianCalendar`, annoté `@XmlSchemaType(name = "date")`, car le contrat déclare `xs:date`. En partie A, c'était un `String` côté Java comme côté XSD (`xs:string`) : n'importe quelle chaîne passait pour une date.

**4. Classe d'exception.**
`LivreIndisponibleFault` (avec `getFaultInfo()` qui renvoie le bean `LivreIndisponible`). wsimport nomme l'exception d'après le **`name` du `wsdl:message`** référencé par le `wsdl:fault`, soit `<wsdl:message name="LivreIndisponibleFault">`. Le bean `LivreIndisponible` tient son nom de l'**élément** XSD de la part.

### Étape 6 — Implémenter et comparer

**1. Le WSDL publié est-il le nôtre ?**
Oui. Avec `wsdlLocation`, Metro publie le fichier fourni tel quel : schéma en ligne, `IsbnType` avec son `xs:pattern`, `dateRetour` et `retourPrevu` en `xs:date`, mêmes noms (`EmpruntPortType`, `EmpruntSoapBinding`). Seul le `soap:address` est réécrit avec l'adresse réelle de publication.

**2. Fallait-il modifier `01-emprunter.xml` ?**
Oui. Le contrat déclare `elementFormDefault="qualified"`, donc `idAdherent` et `isbn` doivent être dans l'espace de noms `http://supnum.mr/bib` : on écrit `<bib:idAdherent>` et `<bib:isbn>` (voir `xml/10-emprunter-contractfirst.xml`).

Avec l'ancien fichier, JAXB ne reconnaît pas les éléments non qualifiés et les ignore. Les deux paramètres valent `null` et `isbn.equals(…)` lève une `NullPointerException`, renvoyée en Fault `S:Server`. Vérifié hors serveur : valider le Body de l'ancien message contre le XSD du WSDL donne *Element 'idAdherent': This element is not expected. Expected is ({http://supnum.mr/bib}idAdherent)*.

On envoie aussi le `SOAPAction` déclaré, `http://supnum.mr/bib/emprunterLivre`. Metro aiguille surtout sur le QName du payload, mais c'est l'action que le contrat impose et que d'autres piles vérifient.

**3. ISBN `978-2-10` et `@SchemaValidation`.**
- **Sans** `@SchemaValidation` : l'ISBN est **accepté**. L'implémentation ne teste que l'ISBN « indisponible », et la réponse est un emprunt `E-2026-0812`. Le motif figure dans le contrat, mais personne ne l'applique.
- **Avec** `@SchemaValidation` (`12-isbn-invalide-contractfirst.xml`) : la requête est **refusée avant d'atteindre le code**, avec une Fault `S:Client` (HTTP 500) dont la `faultstring` est l'erreur du validateur XSD, du type *cvc-pattern-valid: Value '978-2-10' is not facet-valid with respect to pattern '97[89]-\d-\d{2,5}-\d{2,6}-\d' for type 'IsbnType'*. Le contrat devient la règle appliquée, sans une ligne de validation en Java.

**4. Sans `wsdlLocation`.**
Metro ne publie plus notre fichier. Il **régénère** un WSDL à partir des annotations de l'interface et des classes JAXB générées, comme en partie A :
- le schéma passe dans un document séparé (`?xsd=1`) ;
- `IsbnType` et son **motif disparaissent** : `isbn` redevient `xs:string`. Même avec `@SchemaValidation`, `978-2-10` est alors accepté ;
- le binding prend un nom calculé (`EmpruntPortBinding` au lieu de `EmpruntSoapBinding`) et la mise en forme change.

Restent conservés : `xs:date` (grâce à `@XmlSchemaType`), les éléments qualifiés (`package-info`) et le `soapAction` (`@WebMethod(action=…)`).

Le contrat publié n'est donc plus exactement celui convenu : on a perdu l'intérêt du contract-first. Il faut garder `wsdlLocation`.

---

## Conclusion — Choisir et rendre

**1. Deux différences observées entre les WSDL A et B.**
1. **Typage** : en A, `isbn` et `dateRetour` sont des `xs:string` avec `minOccurs="0"`. En B, `isbn` est un `IsbnType` contraint par motif, `dateRetour` un `xs:date`, et les éléments sont obligatoires.
2. **Espaces de noms** : en A, `elementFormDefault` vaut `unqualified` et les paramètres sont sans préfixe. En B, il vaut `qualified` et les paramètres s'écrivent `bib:…`. Le même message ne marche pas sur les deux services.

Autres différences :
- schéma externe (`?xsd=1`) en A, en ligne en B ;
- `soapAction=""` en A, explicite en B ;
- noms dérivés du code en A (`portType EmpruntService`, `EmpruntPortBinding`, message de fault `LivreIndisponibleException`), choisis en B ;
- `rendreLivre` absent du contrat B.

**2. Renommer `dateRetour` dans le code.**
Seul le **projet code-first (A)** voit son contrat changer, et **silencieusement** : le WSDL est régénéré au démarrage avec le nouveau nom, sans que personne n'ait décidé de modifier le contrat.

Les clients générés avec l'ancien WSDL attendent toujours `<dateRetour>`. JAXB ignore l'élément inconnu, donc leur date de retour vaut `null` sans aucune erreur : une rupture de compatibilité invisible jusqu'en production.

En B, le contrat est la source. Le code généré dans `target/` est recréé à chaque build, et changer le nom suppose de modifier le WSDL, donc une décision explicite et versionnée.

**3. Choix d'approche.**
- **Service Paiement** (Scolarité .NET, Bibliothèque PHP, portail Node.js) : **contract-first**. Trois équipes et trois langages partagent le contrat. Il doit être neutre, stable, versionné et validable (types précis, motifs, Faults déclarées). Chaque équipe génère son client depuis le même WSDL. On évite aussi les particularités d'un WSDL dérivé de Java, comme les `minOccurs="0"` partout ou les types trop lâches.
- **Prototype interne de deux jours** : **code-first**. Un seul consommateur, un contrat qui change d'heure en heure, et le WSDL généré gratuitement. Si le prototype part en production, on fige alors le WSDL publié et on bascule en contract-first.

---

## Rendu

`TP1_Nom1_Nom2.zip` contient :
- `emprunt-codefirst/` : projet Maven, partie A, avec le contrôle de l'étape 4 dans `rendreLivre` ;
- `emprunt-contractfirst/` : projet Maven, partie B, avec `@SchemaValidation`. `target/` n'est pas inclus : `mvn generate-sources` le recrée ;
- `xml/` : messages de test ;
- `envoyer.sh` ;
- `reponses.md`.
