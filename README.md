# Gustav Timer

Intervalový časovač pro iPhone navržený pro sport a trénink. Umožňuje sestavit libovolný sled intervalů s názvy a délkami, nastavit počet opakování a spustit timer s vizuální, zvukovou i haptickou zpětnou vazbou.

## Funkce

- **Intervaly** – až 10 intervalů za kolo, každý s vlastním názvem (max. 12 znaků) a délkou 1–600 sekund
- **Kola** – 1–31 opakování nebo nekonečná smyčka
- **Odpočet** – volitelný 3sekundový odpočet před startem
- **Zvuk** – 10 zvukových témat (beep, whistle, gong, bell, bicycle, …) nebo ztlumení
- **Haptika** – vibrace při přechodu mezi intervaly
- **Oblíbené** – ukládání vlastních timerů a rychlý výběr
- **Přednastavené timery** – Tabata, HIIT, EMOM, AMRAP, Meditace
- **Pozadí** – 10 fotografií na pozadí
- **Sdílení** – export libovolného timeru jako deeplink (swipe vlevo v Oblíbených)

---

## Deeplinks

Aplikace zpracovává vlastní URL schéma `gustavtimerapp://` pro načítání timerů z externích zdrojů – webových odkazů, QR kódů, sdílení přes iMessage apod.

### Schéma URL

```
gustavtimerapp://timer?<intervaly>&rounds=<počet>
```

### Formáty intervalů

#### Plný formát – s názvem
Parametr: `název=sekundy`

```
gustavtimerapp://timer?Work=30&Rest=15
```

#### Minimalistický formát – bez názvu
Parametr: jen číslo (sekundy), bez hodnoty. Intervaly se pojmenují automaticky jako „Kolo 1", „Kolo 2" atd.

```
gustavtimerapp://timer?30&15&20
```

#### Kombinace
Oba formáty lze míchat v jednom odkazu.

```
gustavtimerapp://timer?Work=30&15
```

### Parametr `rounds`

| Hodnota | Chování |
|---------|---------|
| `1`–`31` | Pevný počet kol |
| `-1` | Nekonečná smyčka |
| *(neuvedeno)* | Výchozí: nekonečná smyčka (`-1`) |

```
gustavtimerapp://timer?Work=30&Rest=15&rounds=8
gustavtimerapp://timer?30&15&rounds=-1
```

### Limity

| Parametr | Limit |
|----------|-------|
| Počet intervalů | max. 10 |
| Délka intervalu | 1–600 sekund |
| Délka názvu | max. 12 znaků |

Hodnoty mimo rozsah jsou automaticky oříznuty nebo ignorovány.

### Příklady

```
# Tabata
gustavtimerapp://timer?Work=20&Rest=10&rounds=8

# HIIT
gustavtimerapp://timer?Sprint=30&Rest=15&rounds=10

# EMOM
gustavtimerapp://timer?Work=60&rounds=10

# Bezejmenné intervaly
gustavtimerapp://timer?30&15&10

# Nekonečná smyčka
gustavtimerapp://timer?Work=40&Rest=20
```

### Chování po otevření odkazu

1. Aplikace načte intervaly a nastaví počet kol
2. Automaticky otevře nastavení pro kontrolu a případnou úpravu
3. V nastavení se zobrazí informace, že timer byl načten z externího odkazu

### Sdílení timerů

V sekci **Oblíbené** lze swipovat vlevo na libovolný timer a stisknout **Sdílet**. Aplikace vygeneruje deeplink URL se všemi intervaly a počtem kol, který lze poslat přes iMessage, zkopírovat nebo převést na QR kód.

---

## Ostatní deeplinky

```
gustavtimerapp://whatsnew    – zobrazí obrazovku Co je nového
```
