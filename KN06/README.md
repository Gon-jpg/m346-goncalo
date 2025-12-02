# KN06: Skalierung

## Übersicht

In diesem Kompetenznachweis wird eine Java/.NET-Anwendung installiert und verschiedene Skalierungsstrategien (vertikal, horizontal, automatisch) auf AWS implementiert. Die Datenbank wird als SaaS (MongoDB Atlas) betrieben.

**Gewichtung:**
- Teil A: Installation App (50%)
- Teil B: Vertikale Skalierung (10%)
- Teil C: Horizontale Skalierung (20%)
- Teil D: Auto Scaling (20%)

---

## A) Installation App (50%)

### 1. MongoDB Atlas (SaaS-Datenbank)

Anstatt eine eigene Datenbank-Instanz zu hosten, wird MongoDB Atlas als **Software as a Service (SaaS)** verwendet.

#### MongoDB Atlas Konfiguration

| Eigenschaft | Wert |
|-------------|------|
| **Cluster** | m346-cluster.wk57b1t.mongodb.net |
| **Username** | admin |
| **Password** | admin123 |
| **Database** | shop |
| **Type** | M0 (Free Tier) |

#### Netzwerk-Zugriff konfigurieren

Um von AWS EC2-Instanzen auf MongoDB Atlas zuzugreifen, muss der IP-Bereich in den Network Access Settings konfiguriert werden:

**Network Access:**
- IP Whitelist: `0.0.0.0/0` (alle IPs - nur für Test/Entwicklung!)
- Für Produktion: Nur spezifische AWS-IP-Bereiche erlauben

**Connection String:**
```
mongodb+srv://admin:admin123@m346-cluster.wk57b1t.mongodb.net/shop?retryWrites=true&w=majority
```

#### Screenshot: MongoDB Atlas Collections
![MongoDB Collections](./screenshots/cluster-products.png)

*Zeigt die Collections in der shop-Datenbank nach erfolgreicher Initialisierung.*

---

### 2. Webserver mit Java/.NET Application

Eine Java oder .NET Web-API wird auf einer EC2-Instanz installiert. Die Anwendung läuft auf einem eigenen Port (5000/.NET oder 5001/Java) und wird über **Nginx als Reverse Proxy** auf Port 80 verfügbar gemacht.

#### Was ist ein Reverse Proxy?

**Erklärung:**
Ein Reverse Proxy ist ein Server, der **Anfragen von Clients entgegennimmt** und diese an einen oder mehrere Backend-Server weiterleitet.

**In diesem Fall:**
- Nginx nimmt HTTP-Anfragen auf **Port 80** entgegen
- Nginx leitet diese intern an die Java/NET-App auf **Port 5001/5000** weiter
- Der Endbenutzer sieht nur Port 80 (Standard-HTTP)

**Vorteile:**
- Standard-Port 80 statt ungewöhnlicher Port 5001
- SSL-Terminierung möglich
- Load Balancing möglich
- Caching möglich

---

### 3. EC2-Instanz für Webserver

#### Instanz Details (Initial)

| Eigenschaft | Wert |
|-------------|------|
| **Name** | KN06-Web |
| **Instance Type** | t3.micro |
| **OS** | Ubuntu 24.04 LTS |
| **vCPUs** | 2 |
| **Memory** | 1 GB |
| **Storage** | 8 GB |
| **Public IP** | (dynamisch) |

#### Cloud-init Konfiguration

Die vollständige Datei: [`cloud-init-kn06.yaml`](./cloud-init-kn06.yaml)

**Wichtige Komponenten:**

1. **Java/.NET Runtime Installation**
2. **Application Deployment**
3. **Nginx als Reverse Proxy**
4. **MongoDB Connection String**
5. **Systemd Service für die App**

---

### 4. Swagger UI - API Testing

#### Java Version
**URL:** `http://<IP>/swagger-ui.html`
**Backend Port:** 5001

#### .NET Version
**URL:** `http://<IP>/swagger/`
**Backend Port:** 5000

#### Screenshot: Swagger UI
![Swagger UI](./screenshots/swagger-url.png)

*Zeigt die Swagger-Dokumentation der Web-API.*

---

#### Screenshot: Products Endpoint Test
![Products Endpoint](./screenshots/swagger-product-command.png)

*Zeigt erfolgreichen API-Aufruf mit Produkten aus der MongoDB-Datenbank.*

---

### 5. Sicherheitsanalyse: Was macht keinen Sinn in Produktion?

#### Problematische Konfiguration:

```yaml
ssh_pwauth: true
```

**Erklärung:**

Diese Zeile **aktiviert Passwort-Authentifizierung für SSH**. Das ist ein **Sicherheitsrisiko**, weil:

1. **Brute-Force-Angriffe:** Passwörter können durch automatisierte Angriffe erraten werden
2. **Schwache Passwörter:** Benutzer wählen oft unsichere Passwörter
3. **SSH-Keys sind sicherer:** Key-basierte Authentifizierung ist praktisch unknackbar
4. **Best Practice:** In Produktivumgebungen sollte `ssh_pwauth: false` gesetzt sein

**Weitere problematische Teile:**

```yaml
# MongoDB Connection mit Credentials im Klartext
MONGO_CONNECTION_STRING=mongodb+srv://admin:admin123@...
```

- **Credentials im Klartext:** Passwörter sollten über AWS Secrets Manager oder Parameter Store verwaltet werden
- **Schwaches Passwort:** "admin123" ist unsicher
- **0.0.0.0/0 Network Access:** MongoDB sollte nur von spezifischen IPs erreichbar sein

---

## B) Vertikale Skalierung (10%)

**Vertikale Skalierung** bedeutet, die **Ressourcen einer einzelnen Instanz zu erhöhen** (mehr CPU, RAM, Disk).

### 1. Disk-Erweiterung (8 GB → 20 GB)

#### Vorgehensweise:

1. **EC2 Console** → Instances → KN06-Web auswählen
2. **Storage Tab** → Volume ID anklicken
3. **Actions** → **Modify Volume**
4. **Size:** 8 GB → 20 GB
5. **Modify** klicken

**Geht dies im laufenden Betrieb?**
✅ **Ja!** Die Disk kann ohne Stopp der Instanz erweitert werden. Das Dateisystem muss danach mit `sudo growpart` und `sudo resize2fs` erweitert werden.

#### Screenshot: Disk vorher (8 GB)
![Disk Before](./screenshots/web-before.png)

#### Screenshot: Disk nachher (20 GB)
![Disk After](./screenshots/web-after-storage.png)

---

### 2. Instance Type ändern (t3.micro → t2.medium)

#### Vorgehensweise:

1. **EC2 Console** → Instances → KN06-Web auswählen
2. **Instance State** → **Stop Instance** (❗ Instanz muss gestoppt werden)
3. **Actions** → **Instance Settings** → **Change Instance Type**
4. **Instance Type:** t3.micro → t2.medium
5. **Apply** klicken
6. **Instance State** → **Start Instance**

**Geht dies im laufenden Betrieb?**
❌ **Nein!** Die Instanz muss gestoppt werden, um den Instance Type zu ändern.

#### Ressourcen-Vergleich:

| Instance Type | vCPUs | Memory | Storage | Kosten (ca.) |
|---------------|-------|--------|---------|--------------|
| **t3.micro** (vorher) | 2 | 1 GB | 8 GB | $0.0104/h |
| **t2.medium** (nachher) | 2 | 4 GB | 20 GB | $0.0464/h |

#### Screenshot: Instance Type vorher (t3.micro)
![Instance Before](./screenshots/web-before.png)

#### Screenshot: Instance Type nachher (t2.medium)
![Instance After](./screenshots/web-after-instance-type.png)

---

## C) Horizontale Skalierung (20%)

**Horizontale Skalierung** bedeutet, **mehrere Instanzen** der Anwendung zu betreiben und den Traffic über einen **Load Balancer** zu verteilen.

### Architektur-Übersicht

```
                    ┌─────────────────┐
                    │    Internet     │
                    └─────────────────┘
                            │
                            │ HTTP (Port 80)
                            ▼
                    ┌─────────────────┐
                    │  Load Balancer  │
                    │    LB-KN06      │
                    │  DNS: lb-kn06-  │
                    │  1772871207...  │
                    └─────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  KN06-Web1  │ │  KN06-Web2  │ │  KN06-Web3  │
    │  Port 80    │ │  Port 80    │ │  Port 80    │
    └─────────────┘ └─────────────┘ └─────────────┘
            │               │               │
            └───────────────┼───────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │    MongoDB Atlas      │
                │  m346-cluster...net   │
                └───────────────────────┘
```

---

### 1. Load Balancer erstellen

#### Load Balancer Details

| Eigenschaft | Wert |
|-------------|------|
| **Name** | LB-KN06 |
| **Type** | Application Load Balancer (ALB) |
| **Scheme** | Internet-facing |
| **IP Address Type** | IPv4 |
| **DNS Name** | lb-kn06-1772871207.us-east-1.elb.amazonaws.com |

#### Listener Configuration

| Protocol | Port | Action |
|----------|------|--------|
| HTTP | 80 | Forward to TG-KN06 |

#### Screenshot: Load Balancer
![Load Balancer](./screenshots/load-balancer-details.png)

---

### 2. Target Group erstellen

#### Target Group Details

| Eigenschaft | Wert |
|-------------|------|
| **Name** | TG-KN06 |
| **Target Type** | Instances |
| **Protocol** | HTTP |
| **Port** | 80 |
| **VPC** | Default VPC |

#### Health Check Konfiguration

| Parameter | Wert |
|-----------|------|
| **Protocol** | HTTP |
| **Path** | `/shop/alive` |
| **Port** | Traffic port (80) |
| **Healthy Threshold** | 2 |
| **Unhealthy Threshold** | 3 |
| **Timeout** | 5 seconds |
| **Interval** | 30 seconds |
| **Success Codes** | 200 |

**Wichtig:** Der `/shop/alive` Endpoint ist ein Health-Check-Endpoint, der von der Application bereitgestellt wird und einfach "OK" zurückgibt, wenn die App läuft.

#### Screenshot: Target Group mit Health Status
![Target Group](./screenshots/target-groups-details.png)

---

### 3. Instanzen zum Load Balancer hinzufügen

Mindestens **zwei Instanzen** werden als Targets registriert:

| Instanz | Private IP | Status | Health Status |
|---------|------------|--------|---------------|
| KN06-Web1 | 172.31.x.x | running | healthy |
| KN06-Web2 | 172.31.y.y | running | healthy |

#### Screenshot: Registered Targets
![Registered Targets](./screenshots/target-groups-details.png)

---

### 4. Swagger via Load Balancer URL

#### URL-Test:
**Load Balancer URL:** `http://lb-kn06-1772871207.us-east-1.elb.amazonaws.com/swagger-ui.html`

Der Load Balancer verteilt die Anfragen automatisch auf beide Instanzen (Round Robin).

#### Screenshot: Swagger über Load Balancer
![Swagger via LB](./screenshots/lb-url-swagger.png)

*URL zeigt Load Balancer DNS-Name, nicht die IP der Instanz.*

---

### 5. DNS-Konfiguration für Custom Domain

**Frage:** Wie müsste der DNS konfiguriert werden, damit die App unter `app.tbz-m346.ch` verfügbar ist?

**Antwort:**

Man muss einen **CNAME Record** im DNS erstellen:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | app.tbz-m346.ch | lb-kn06-1772871207.us-east-1.elb.amazonaws.com | 300 |

**Erklärung:**
- **CNAME (Canonical Name):** Leitet einen Domain-Namen auf einen anderen Domain-Namen um
- `app.tbz-m346.ch` → `lb-kn06-1772871207.us-east-1.elb.amazonaws.com`
- Der Browser löst `app.tbz-m346.ch` auf und wird automatisch zum Load Balancer weitergeleitet

**Alternative:**
Man könnte auch einen **A-Record mit Alias** verwenden (AWS Route 53 Spezialfunktion), der direkt auf den Load Balancer zeigt.

---

### 6. Security Groups für Load Balancer

#### Security Group für Load Balancer

| Type | Protocol | Port | Source | Beschreibung |
|------|----------|------|--------|--------------|
| HTTP | TCP | 80 | 0.0.0.0/0 | Öffentlicher Zugriff |

#### Security Group für Web-Instanzen

| Type | Protocol | Port | Source | Beschreibung |
|------|----------|------|--------|--------------|
| SSH | TCP | 22 | 0.0.0.0/0 | SSH-Zugriff |
| HTTP | TCP | 80 | sg-xxxxxxxx (LB SG) | Traffic vom Load Balancer |

**Wichtig:** Die Web-Instanzen sollten nur Traffic vom Load Balancer akzeptieren, nicht direkt aus dem Internet!

---

### 7. Statische IPs nicht mehr notwendig

**Vorher (KN05):** Elastic IP für Webserver notwendig

**Jetzt (KN06):** ❌ **Keine Elastic IPs mehr!**

**Begründung:**
- Externe Clients verbinden sich nur zum Load Balancer (konstanter DNS-Name)
- Die Web-Instanzen brauchen keine statischen öffentlichen IPs
- Load Balancer verwaltet die Routing-Logik intern
- Instanzen können jederzeit ersetzt werden, ohne dass sich die externe URL ändert

---

## D) Auto Scaling (20%)

**Auto Scaling** ermöglicht es, Instanzen **automatisch zu ersetzen oder hinzuzufügen/zu entfernen**, basierend auf definierten Regeln.

### Architektur mit Auto Scaling

```
                    ┌─────────────────┐
                    │  Load Balancer  │
                    │    LB-KN06      │
                    └─────────────────┘
                            │
                            │
                            ▼
                    ┌─────────────────┐
                    │  Target Group   │
                    │    TG-KN06      │
                    └─────────────────┘
                            │
                            │
                            ▼
            ┌───────────────────────────────┐
            │   Auto Scaling Group          │
            │      ASG-KN06                 │
            │                               │
            │  Desired: 2                   │
            │  Min: 2, Max: 5               │
            │                               │
            │  Verwendet: LT-KN06           │
            └───────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  Instance 1 │ │  Instance 2 │ │  Instance 3 │
    │ (automatisch│ │ (automatisch│ │ (optional)  │
    │  erstellt)  │ │  erstellt)  │ │             │
    └─────────────┘ └─────────────┘ └─────────────┘
```

---

### 1. Launch Template erstellen

Ein **Launch Template** definiert, wie neue Instanzen erstellt werden sollen.

#### Launch Template Details

| Eigenschaft | Wert |
|-------------|------|
| **Name** | LT-KN06 |
| **AMI** | Ubuntu 24.04 LTS |
| **Instance Type** | t2.medium (nach Skalierung in Teil B) |
| **Key Pair** | vorname2 |
| **Security Group** | SG-Webserver |
| **User Data** | cloud-init-kn06.yaml |

**Wichtig:** Das Launch Template verwendet die gleiche Cloud-Init Konfiguration wie in Teil A!

#### Screenshot: Launch Template
![Launch Template](./screenshots/log-could-init.png)

---

### 2. Auto Scaling Group erstellen

#### Auto Scaling Group Details

| Eigenschaft | Wert |
|-------------|------|
| **Name** | ASG-KN06 |
| **Launch Template** | LT-KN06 |
| **VPC** | Default VPC |
| **Subnets** | us-east-1a, us-east-1b |
| **Load Balancer** | LB-KN06 (Target Group: TG-KN06) |
| **Health Check Type** | ELB |
| **Health Check Grace Period** | 300 seconds |

#### Skalierungs-Konfiguration

| Parameter | Wert |
|-----------|------|
| **Desired Capacity** | 2 |
| **Minimum Capacity** | 2 |
| **Maximum Capacity** | 5 |

**Bedeutung:**
- **Desired:** Auto Scaling versucht immer, 2 Instanzen zu haben
- **Minimum:** Mindestens 2 Instanzen müssen laufen
- **Maximum:** Maximal 5 Instanzen (bei Scale-Out Events)

#### Screenshot: Auto Scaling Group
![Auto Scaling Group](./screenshots/asg-details.png)

---

### 3. Auto Scaling Test - Instanz ersetzen

**Test:** Was passiert, wenn eine Instanz manuell terminiert wird?

#### Vorgehensweise:

1. **Ausgangszustand:** 2 Instanzen laufen (Desired: 2)
2. **Aktion:** Eine Instanz manuell terminieren
3. **Erwartung:** Auto Scaling erkennt, dass nur noch 1 Instanz läuft
4. **Reaktion:** Auto Scaling startet automatisch eine neue Instanz

#### Screenshot: Auto Scaling Activity Log
![ASG Activity Log](./screenshots/asg-log.png)

*Zeigt die Auto Scaling Group Activity History mit terminierten und neu gestarteten Instanzen.*

**Ergebnis:**
- ✅ Auto Scaling hat die terminierte Instanz erkannt
- ✅ Eine neue Instanz wurde automatisch gestartet
- ✅ Nach wenigen Minuten sind wieder 2 Instanzen aktiv (Desired Capacity erreicht)
- ✅ Load Balancer Health Check zeigt beide Instanzen als "healthy"

---

### 4. Auto Scaling Policies (Optional)

Neben der automatischen Ersetzung können auch **Scaling Policies** definiert werden:

#### Beispiel: CPU-basierte Skalierung

| Policy | Trigger | Action |
|--------|---------|--------|
| **Scale Out** | CPU > 70% für 5 Minuten | +1 Instanz hinzufügen |
| **Scale In** | CPU < 30% für 5 Minuten | -1 Instanz entfernen |

**Wichtig:** In dieser Aufgabe wurde nur die automatische Ersetzung (Self-Healing) getestet, nicht die dynamische Skalierung basierend auf Metriken.

---

## Erkenntnisse

### Vertikale vs. Horizontale Skalierung

| Aspekt | Vertikal | Horizontal |
|--------|----------|-----------|
| **Definition** | Mehr Ressourcen pro Instanz | Mehr Instanzen |
| **Downtime** | Ja (für Instance Type Change) | Nein |
| **Kosten** | Teurer pro Instanz | Verteilte Kosten |
| **Flexibilität** | Begrenzt durch Instance Types | Fast unbegrenzt |
| **Redundanz** | Single Point of Failure | Hohe Verfügbarkeit |
| **Anwendungsfall** | Datenbanken, monolithische Apps | Webserver, Microservices |

### Load Balancer vs. Elastic IP

| Aspekt | Elastic IP | Load Balancer |
|--------|------------|---------------|
| **Use Case** | Einzelne Instanz | Mehrere Instanzen |
| **Verfügbarkeit** | Single Point of Failure | Hohe Verfügbarkeit |
| **Skalierung** | Nicht möglich | Automatisch |
| **DNS** | IP-Adresse | DNS-Name |
| **Kosten** | $0 (wenn attached) | ~$16/Monat |

### Auto Scaling Vorteile

1. **Self-Healing:** Fehlerhafte Instanzen werden automatisch ersetzt
2. **Kostenoptimierung:** Scale-In bei wenig Last
3. **Performance:** Scale-Out bei hoher Last
4. **Wartungsfenster:** Instanzen können ohne Downtime ersetzt werden

### Reverse Proxy Vorteile

1. **Standard-Ports:** Client verbindet sich zu Port 80, nicht 5001
2. **SSL-Terminierung:** HTTPS kann auf Proxy-Ebene implementiert werden
3. **Load Balancing:** Ein Nginx kann zu mehreren Backend-Apps weiterleiten
4. **Caching:** Statische Inhalte können gecacht werden

---

## Zusammenfassung

| Teil | Beschreibung | Status |
|------|--------------|--------|
| A | Java/.NET App mit MongoDB Atlas installiert, Reverse Proxy konfiguriert | ✅ |
| A | Swagger UI funktioniert, Products-Endpoint liefert Daten | ✅ |
| A | Sicherheitsanalyse: ssh_pwauth problematisch identifiziert | ✅ |
| B | Disk von 8 GB auf 20 GB erweitert (im laufenden Betrieb) | ✅ |
| B | Instance Type von t3.micro auf t2.medium geändert (mit Stopp) | ✅ |
| C | Load Balancer und Target Group erstellt | ✅ |
| C | Health Check auf /shop/alive konfiguriert | ✅ |
| C | Swagger via Load Balancer URL funktioniert | ✅ |
| C | DNS-Konfiguration (CNAME) erklärt | ✅ |
| D | Launch Template erstellt | ✅ |
| D | Auto Scaling Group konfiguriert (Desired: 2, Min: 2, Max: 5) | ✅ |
| D | Auto Scaling Test: Instanz terminiert → automatisch ersetzt | ✅ |

**Ergebnis:** Eine vollständig skalierbare, hochverfügbare Web-Anwendung mit automatischer Fehlerbehebung und Load Balancing.
