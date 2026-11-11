# Gustav Timer – co testovat vždycky

Checklist před každým releasem a po větších změnách. Každá sekce říká **co**
zkusit a **co má vyjít**. Hodnoty limitů jsou z kódu (`SharedTimerLink.Limits`,
`AppConfig`, `RemoteContentPolicy`) – když se změní tam, změň je i tady.

Na konci je záznam posledního průchodu (11. 11. 2026, větev `feature/api`,
verze 2.4.0): co se ověřilo a co zůstalo neověřené.

---

## 0 · Jak testovat

**Sestavení a spuštění v simulátoru**

```bash
xcodebuild -scheme GustavTimer -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

**Unit testy** (Swift Testing – souhrn „Executed 0 tests“ od XCTestu je
v pořádku, hledej řádek `Test run with N tests … passed`):

```bash
xcodebuild test -scheme GustavTimer \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

Filtr `-only-testing:GustavTimerTests/<Suite>` na suity ze Swift Testing
nefunguje spolehlivě – v průchodu 11. 11. nespustil nic. Spouštěj celou sadu.

**Deeplinky v simulátoru**

```bash
xcrun simctl openurl booted 'gustavtimerapp://timer?Work=40&Rest=20&rounds=4'
```

Simulátor u vlastního schématu nic nepotvrzuje, aplikace ukáže dialog
„Načíst timer?“.

**Klepání v simulátoru**: po přechodu mezi obrazovkami nebo po swipu počkej
asi sekundu, než se seznam zastaví. Klepnutí během dojezdu trefí jiný řádek
(v průchodu to vyrobilo falešný nález „vybralo se 29 místo 31 kol“).

**Debug menu vzdáleného obsahu** (jen DEBUG): v nastavení 5× klepnout na
číslo verze.

---

## 1 · Automatické testy

- [ ] Celá sada projde (v průchodu 11. 11.: 153 testů v 10 suitách).
- [ ] Nová logika v `SharedTimerLink`, `RemoteContent*`, `TimerEngine` má
      testy – ne jen ruční průchod.

---

## 2 · Nastavení timeru

### Intervaly

- [ ] Pole délky intervalu: prázdné → po opuštění pole se hodnota nezmění
      nebo zvedne na 1 (nesmí zůstat prázdný interval).
- [ ] `0` → po opuštění pole `1`.
- [ ] Víc než 600 (např. `9991`) → po opuštění pole `600`.
- [ ] Součty („Jedno kolo trvá…“, „Celkový čas timeru je…“) sedí po každé
      změně: 5m 01s × 6 = 30m 06s, 15m × 6 = 1h 30m, 15m × 29 = 7h 15m.
- [ ] Přidat interval až do limitu **10 intervalů** – tlačítko se pak
      vypne / nic nepřidá.
- [ ] Smazat poslední zbývající interval – nesmí vzniknout timer bez intervalů.
- [ ] Přeřazení a mazání v režimu úprav (tlačítko s posuvníky vpravo nahoře).
- [ ] Název timeru: prázdný, 64+ znaků, emoji, diakritika.

### Kola

- [ ] Seznam je 1–31; výběr **1** a **31** (poslední položka) se uloží
      a ukáže v řádku „Kola“.
- [ ] Přepínač „Opakování“: zapnutí skryje seznam, vypnutí vrátí **dříve
      zvolený počet** (ne 1), i když se obrazovka otevřela s hodnotou
      nastavenou dřív.
- [ ] Součet času při opakování (∞) se nepočítá / neukazuje nesmysl.

### Odezva

- [ ] Vibrace: zapnout / vypnout, přetrvá po zavření nastavení.
- [ ] Odpočet před startem: zapnout / vypnout; na hlavní obrazovce se
      projeví hned po startu (3-2-1 nebo ne).
- [ ] Tikání: vypnuto / každou sekundu / před koncem intervalu. Po vypnutí
      a zapnutí se vrátí **poslední zvolený režim**; řádek v nastavení
      ukazuje „Vypnuto“ při vypnutí.
- [ ] Zvuk: vypnout a zapnout vrátí poslední zvolený zvuk (zkoušet i poslední
      v seznamu, Bublinu); „žádný“ se ukáže v řádku, když je zvuk vypnutý.
- [ ] Každý zvuk v seznamu se při výběru přehraje (na zařízení, ne v simulátoru).

### Pozadí

- [ ] Všechna vestavěná pozadí, včetně **světlého** (mramor) – čitelnost
      limetkového textu a ovládacích prvků.
- [ ] Vybrané pozadí se po návratu na timer změní a přežije restart.
- [ ] Vybrané **vzdálené** pozadí, které zmizí z API / mu skončí platnost →
      aplikace se vrátí na výchozí vestavěné (viz sekce 5).

### Napříč nastavením

- [ ] Každá změna přežije zavření sheetu a restart aplikace.
- [ ] Změna nastavení za běhu timeru nerozbije aktuální interval.
- [ ] Uložení do oblíbených a výběr oblíbeného přenese **všechno**:
      intervaly, kola, zvuk, vibrace, tikání, odpočet 3-2-1 (návrh
      `GustavTimer-Navrh-Nastaveni-A-Deeplinku.md` popisuje, kde se to dřív
      ztrácelo).

---

## 3 · Běh timeru

- [ ] Start → odpočet 3-2-1 (je-li zapnutý) → první interval → další interval
      → další kolo → konec. Popisky („Work (1/6)“), progress bar a tlačítka
      odpovídají stavu.
- [ ] Pauza, pokračování, přeskočení intervalu, reset.
- [ ] Poslední interval posledního kola: správný konec, správný zvuk.
- [ ] Nekonečné opakování: neukončí se samo, správně počítá kola.
- [ ] Interval 1 s: nic se nezasekne (zvuk + vibrace + tikání naráz).
- [ ] Přechod do pozadí a zamknutí telefonu uprostřed intervalu: čas po
      návratu sedí, zvuk / vibrace na konci intervalu proběhne.
- [ ] Hovor nebo jiná aplikace přehrává zvuk – timer ho nepřeruší natrvalo.
- [ ] Rotace, Dynamic Type nejvyšší velikost, tmavý a světlý režim.

---

## 4 · Deeplinky

Formy odkazu: `https://gustavtraining.com/t?…` (Universal Link) a
`gustavtimerapp://timer?…`; obě musí dát **stejný** výsledek.

Limity parseru: max **10** intervalů, hodnota **1–600**, kola **1–31**
(`-1` = ∞), název max **64** znaků. Rezervované klíče: `rounds`, `_title`,
`_sound`, `_vibe`, `_tick` (`0`/`1`/`3`), `_cd`.

### Timer odkazy

- [ ] Plný odkaz (`Work=40&Rest=20&rounds=4&_title=…&_sound=off&_vibe=0&_tick=3&_cd=1`):
      dialog „Načíst timer?“ ukáže název, intervaly a kola; po „Načíst“
      sedí **všechno** (intervaly, kola, název, zvuk, vibrace, tikání, odpočet).
- [ ] „Zrušit“ nic nezmění.
- [ ] **Chybějící parametr = zachovej současné**: odkaz bez `_sound`/`_vibe`/
      `_tick`/`_cd` nesmí přepsat uživatelovo nastavení.
- [ ] `rounds=999` → 31, `rounds=-1` → ∞, bez `rounds` → ∞, `rounds=abc` → ignoruje se.
- [ ] `Work=0`, `Rest=601`, `x=abc`, prázdná hodnota → ty části se zahodí.
- [ ] **Odkaz bez jediného platného intervalu** → žádný dialog, timer beze změny.
- [ ] Víc než 10 intervalů → načte se prvních 10, `rounds` se přesto přečte.
- [ ] Název delší než 64 znaků → oříznutý; `%20`, diakritika, emoji v názvu.
- [ ] Duplicitní klíče (`_title` dvakrát) → vyhrává první.
- [ ] Trackovací parametry (`utm_*`, `fbclid`, `gclid`) se ignorují.
- [ ] Odkaz ve formátu verze 2.2.1 (jen intervaly a kola) pořád funguje.
- [ ] Odkaz přijde za běhu timeru – nepřepíše ho bez potvrzení.
- [ ] Odkaz přijde, když je otevřené nastavení nebo jiný sheet.
- [ ] Odkaz přijde za studena (aplikace není spuštěná) i z pozadí.
- [ ] Sdílení vlastního timeru → odkaz se na druhém zařízení načte stejně
      (kruhový test: generátor ↔ parser).

### Odkazy na obrazovky

- [ ] `gustavtimerapp://settings/background` → otevře nastavení rovnou na Pozadí.
- [ ] Stejný odkaz podruhé, když už tam jsem → obrazovka se **nezdvojí**
      (jedno „zpět“ vede na kořen nastavení).
- [ ] `gustavtimerapp://settings/neexistuje`, `…/background/dalsi`,
      velká písmena → tiše se ignoruje, nic se nerozbije.
- [ ] `gustavtimerapp://whatsnew` → otevře „Co je nového“.
- [ ] Odkaz otevřený z banneru uvnitř aplikace jde přes `AppLinkRouter`,
      ne do Safari.

### Universal Links

- [ ] **Jen na reálném zařízení** (v simulátoru se `https://gustavtraining.com/t?…`
      otevře v Safari, i když je vše správně). Ověř, že odkaz z Poznámek /
      Zpráv otevře aplikaci a že `applinks:` v entitlements sedí na
      `gustavtraining.com` i `www.gustavtraining.com`.
- [ ] Odkaz v Safari, když aplikace není nainstalovaná → web, ne chyba.

---

## 5 · Obsah z externího zdroje (API)

Endpoint: `AppConfig.remoteContentURL`
(`https://www.gustavtraining.com/wp-json/gustav-timer/v1/content`).
Aplikace jede vždy z uložené konfigurace, síť jen na pozadí aktualizuje.

### Co endpoint vrací

- [ ] `curl` na endpoint → HTTP 200, `schemaVersion` = 1, velikost pod 512 kB.
- [ ] Obrázky bannerů a pozadí jsou na `gustavtraining.com`
      (`wp-content/uploads`), každý do 10 MB, jde o platný obrázek.
- [ ] `url` bannerů, které aplikace umí otevřít (YouTube, App Store, web,
      `gustavtimerapp://…`, sdílený timer).

### Synchronizace

- [ ] První spuštění bez uložených dat → vestavěný obsah, žádné čekání
      ani loading, po synchronizaci se obsah objeví.
- [ ] Automaticky nejvýš **1× za 24 h** od posledního úspěchu; po neúspěchu
      při dalším otevření.
- [ ] Debug menu → „Vynutit stažení API“: výsledek „úspěch“, počty
      bannerů / odkazů / pozadí odpovídají endpointu.
- [ ] Nový obsah se zobrazí **hned**, bez restartu (banner nahoře v nastavení,
      sekce „Více“).
- [ ] Filtry: odkazy a bannery podle **jazyka** (`cs`/`en`/`null`),
      **platnosti** (`startAt`/`endAt`), **verze aplikace**
      (`minAppVersion`/`maxAppVersion`) – počet „uloženo / zobrazeno“
      v debug menu to ukáže (v průchodu: odkazy 8 / 4 pro češtinu).
- [ ] Banner typu, který tahle verze nezná → zobrazí se bez ikony, neshodí aplikaci.
- [ ] Banner s odkazem, který verze neumí otevřít, se nezobrazí.
- [ ] Banner se střídá (karusel); klepnutí otevře správnou `url`.

### Selhání – aplikace musí zůstat u starého obsahu

- [ ] Bez sítě / letecký režim při synchronizaci → beze změny, chyba v debug menu.
- [ ] HTTP 404 / 500 / vypršený timeout (30 s).
- [ ] Neplatný JSON, chybějící povinné pole.
- [ ] Jiná `schemaVersion` než 1 → odmítne se, zůstane uložená konfigurace.
- [ ] Konfigurace nad 512 kB.
- [ ] Obrázek nad 10 MB, nečitelný obrázek, obrázek z cizí domény →
      celá aktualizace se zahodí (nic napůl).
- [ ] Selhání uprostřed stahování obrázků → příští pokus už stažené nestahuje znovu.
- [ ] Debug menu: „Smazat stažená data“ → vestavěný obsah, vybrané vzdálené
      pozadí se přepne na výchozí; timery a nastavení zůstanou.
- [ ] Změna jazyka zařízení → obsah se přefiltruje.

---

## 6 · Ostatní

- [ ] Onboarding (čistá instalace).
- [ ] Oblíbené: přidat, přejmenovat, smazat, přeřadit, prázdný stav.
- [ ] Sdílení timeru (share sheet).
- [ ] Odkaz „Ohodnoť Gustav Timer“ (zobrazí se, když nejsou vzdálené odkazy).
- [ ] Analytika (TelemetryDeck) neposílá nic, co nemá, a nespadne offline.
- [ ] Migrace nastavení ze starší verze (`SettingsMigration`): upgrade přes
      dřívější build s uloženými timery.
- [ ] Apple Watch (sdílený kód `Shared/`), pokud je ve verzi.
- [ ] Lokalizace: čeština i angličtina, žádné klíče typu `IS_LOOPING`
      v UI, žádné useknuté texty.

---

## Záznam průchodu – 11. 11. 2026

Větev `feature/api`, verze 2.4.0 (1), iPhone 18 Pro (iOS 27.0, simulátor),
Debug sestavení.

### Ověřeno (bez nálezu)

- Sestavení a spuštění; start timeru.
- Pole intervalu: prázdné, `0` → 1, `9991` → 600; součty času.
- Kola: ∞ zapnutí / vypnutí vrací 6, výběr 31.
- Vibrace a odpočet (přepínače), tikání (vrací režim, „Vypnuto“ v řádku),
  zvuk (vrací Bublinu), pozadí (světlý mramor je čitelný).
- Deeplinky: plný odkaz, `rounds=999`, chybějící parametry zachovají
  nastavení, odkaz bez platného intervalu je tichý, `settings/background`
  včetně opakování, `settings/neexistuje`.
- API: živý endpoint, ruční synchronizace (5/5 bannerů, 8/4 odkazů),
  okamžité obnovení sekce „Více“.
- Unit testy: 153 testů v 10 suitách prošlo.

### Neověřeno

- Zvuk, vibrace, tikání **poslechem / hmatem** (simulátor).
- Celý běh timeru do konce, ∞ kola, pozadí aplikace / zamknutí.
- Universal Link `https://gustavtraining.com/t?…` (v simulátoru skončil
  v Safari) – ověřit na zařízení.
- `gustavtimerapp://whatsnew`.
- Selhání sítě, vadný JSON, cizí schéma, obří soubory (kryjí je jen unit
  testy, v aplikaci se nezkoušely).
- Vzdálená pozadí (endpoint jich nyní vrací 0), klepnutí na banner,
  banner typu timer.
- Oblíbené, sdílení, onboarding, migrace, dark mode, Dynamic Type, angličtina.

### Postřehy k posouzení (nejsou to potvrzené chyby)

1. **Dialog „Načíst timer?“ neříká, že odkaz přepíše zvuk, vibrace, tikání
   a odpočet.** Ukazuje jen název, intervaly a kola, ale odkaz z v2.4
   nastavení mění (to jsem viděl: po načtení bylo „Zvuk: žádný“, vibrace
   vypnuté). Rozhodni, jestli to uživateli ukázat.
2. **Po potvrzení odkazu se samo otevře nastavení** s načteným timerem.
   Vypadá to záměrně, ale ověř záměr – klepnutí na „UPRAVIT“ hned po
   „Načíst“ pak trefí tlačítko v už otevřeném nastavení a přepne režim úprav.
3. **Neznámý klíč v odkazu vytvoří interval** (`abc=1` → interval „abc“, 1 s,
   `Wrok=40` místo `Work` → interval „Wrok“). Odpovídá dokumentaci parseru,
   ale překlep v ručně psaném odkazu se projeví jen jako divný interval.
4. **Součet času u pole intervalu se přepočítá až po opuštění pole**,
   ne při psaní. Kosmetické.
5. **Debug menu:** „Poslední úspěch … za 0 sekund“ místo „před 0 sekundami“
   hned po synchronizaci. Jen DEBUG.
