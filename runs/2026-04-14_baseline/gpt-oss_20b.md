# gpt-oss:20b

## Francais pur (style + accents)

**Stats** : duree=191s, eval=139.56s, tokens=322, vitesse=2.3 t/s

**Reponse** :
```
Nous aimerions organiser une réunion, si votre planning le permet, pour discuter d’une collaboration potentielle. Cette collaboration pourrait être bénéfique pour les deux parties.
```

---

## Raisonnement logique

**Stats** : duree=209s, eval=186.58s, tokens=132, vitesse=.7 t/s

**Reponse** :
```
15
```

---

## Extraction JSON structuree

**Stats** : duree=251s, eval=219.62s, tokens=430, vitesse=1.9 t/s

**Reponse** :
```
{"nom":"Sophie Martin","entreprise":"Ambioz","besoin":"CRM pour son équipe de 5 commerciaux","budget":8000,"timeline":"juin"}
```

---

## Resume business (brief client)

**Stats** : duree=530s, eval=512.69s, tokens=1810, vitesse=3.5 t/s

**Reponse** :
```
- **Adoptez HubSpot Free CRM (ou Streak) :** plateforme unique qui intègre Gmail, Google Calendar et notes ; pas de formation longue, prête à l’emploi dès le premier jour.  
- **Importez vos données Excel et créez des modèles d’e‑mail/automation en < 2 h :** utilisez Zapier si besoin pour synchroniser les derniers champs.  
- **Organisez un “kick‑off” de 30 min par associé + guide rapide :** mettez en place des rappels hebdomadaires, surveillez l’usage et ajustez rapidement.
```

---

## Code Python

**Stats** : duree=147s, eval=121.27s, tokens=300, vitesse=2.4 t/s

**Reponse** :
```
from datetime import datetime, date

def parse_date(s: str) -> date:
    for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    raise ValueError(f"Invalid date format: {s}")
```

---

