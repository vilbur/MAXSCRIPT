# Material ID Manager — Redesign Specification

## 1. Účel nástroje

Material ID Manager slouží k rychlé a konzistentní správě Material ID na polygonálních objektech v 3ds Max.

Nástroj podporuje dva paralelní způsoby práce:

- **Přímé Material ID na meshi** — Material ID je zapsané přímo do polygonů přes Editable Poly nebo Edit Poly.
- **Dynamické Material ID přes modifier stack** — výběr polygonů je definovaný pomocí Volume Select a následný Material modifier přiřazuje zvolený Material ID dynamicky.

Oba systémy jsou nezávislé a mohou být použité současně na stejném objektu.

## 2. Struktura UI

Dialog obsahuje dva samostatné rollouty pod sebou.

### Material IDs

Horní rollout je hlavní rozhraní pro práci s Material ID.

Každé ID má vlastní tlačítko a vedle něj editovatelný významový název. Výchozí příklady:

- `1 — Walls`
- `2 — Walls`
- `3 — Walls`
- `4 — Floors`
- `5 — Ceiling`
- `6 — Balcony Exterior`
- `7 — Balcony Interior`

Názvy jsou pouze uživatelská metadata. Číselné Material ID je vždy explicitní hodnota tlačítka, na které uživatel kliknul.

### Volume Select / Material Stack

Druhý rollout spravuje dynamické dvojice:

`Volume Select + Material modifier`

Obsahuje vytvoření Volume Selectu, seznam existujících dvojic a ovládání gizma.

Tento rollout neurčuje Material ID podle pozice ve stacku. Číslo Material ID vždy pochází z horního rollouta.

## 3. Material ID button behavior

Každé Material ID tlačítko má dvě akce:

- **LMB — Select** faces s tímto Material ID.
- **RMB — Assign** toto Material ID do aktuálního pracovního kontextu.

Material ID je vždy explicitní kliknutá hodnota. Nesmí existovat vazba typu `modifier index = Material ID`.

## 4. LMB — Select by Material ID

LMB vybere všechny faces, které mají kliknuté Material ID, a nechá výběr viditelný v Polygon subobject režimu.

### Když je aktivní Editable Poly

Použije se přímo aktuální Editable Poly a zobrazí se odpovídající face selection.

### Když je aktivní Edit Poly

Použije se přímo aktuální Edit Poly a zobrazí se odpovídající face selection.

### Když není aktivní použitelný poly editor

Pokud aktuální stack končí například Material modifierem, Volume Selectem nebo jiným modifierem a uživatel chce s výsledkem dál pracovat, nástroj automaticky přidá nový Edit Poly.

Nový Edit Poly se přidá pouze tehdy, když aktuální pracovní kontext není Editable Poly nebo Edit Poly.

Pokud je aktivní Volume Select patřící do dvojice, nový Edit Poly se vloží nad jeho párový Material modifier, aby dvojice `Volume Select + Material` zůstala vedle sebe a nebyla roztržená.

Výsledný Edit Poly zůstane aktivní na Polygon levelu a výběr je okamžitě připravený k další editaci.

## 5. RMB — Assign Material ID

RMB přiřadí přesně kliknuté Material ID podle aktuálního Modify-panel kontextu.

### Editable Poly / Edit Poly

Pokud je aktivní Editable Poly nebo Edit Poly, ID se zapíše přímo do aktuálně vybraných faces.

### Aktivní Material modifier

Pokud je aktivní Material modifier, RMB nastaví jeho `materialID` přímo na kliknutou hodnotu.

### Aktivní Volume Select

Pokud je aktivní Volume Select, nástroj najde Material modifier přímo nad ním v jeho spravované dvojici a nastaví Material ID na kliknutou hodnotu.

Volume Select samotný Material ID neurčuje. Je pouze dynamický zdroj selection.

## 6. Explicitní Material ID

Zakázaná logika:

- první Material modifier = ID 1
- druhý Material modifier = ID 2
- stack index = Material ID
- automatické renumberování Material modifierů podle pořadí

Správná logika:

`Material ID = číslo Material ID tlačítka, na které uživatel explicitně kliknul.`

Synchronizace Volume Select / Material dvojic smí pouze opravovat chybějící párový Material modifier. Existující Material ID nesmí měnit.

## 7. Volume Select creation workflow

Volume Select používá původní polygon selection pouze jako dočasný bootstrap pro Auto Fit gizma.

Postup:

1. Musí být aktivní přesný Editable Poly nebo Edit Poly kontext, který vlastní zdrojovou face selection.
2. Zdrojová face selection se přečte a ověří.
3. Zdrojový poly kontext se přepne na Face/Polygon level bez změny samotné selection.
4. Přidá se Volume Select.
5. Volume Select provede svůj počáteční Auto Fit podle zdrojové selection.
6. Z výsledku se uloží přesná světová velikost a pozice gizma.
7. Auto Fit se vypne.
8. Gizmo se obnoví na uloženou velikost a pozici.
9. `center.z` se nastaví na přesný spodní okraj gizma.
10. Přímo nad Volume Select se přidá párový Material modifier s výchozím explicitním ID 1.
11. Původní face selection se v přesném zdrojovém Editable Poly / Edit Poly kontextu vyčistí.
12. Po deselectu se znovu přepočítá scale potřebný pro zachování původní světové velikosti gizma a obnoví se původní pozice.
13. Ověří se, že Auto Fit zůstává vypnutý, velikost a pozice gizma jsou zachované a jeho spodní okraj zůstává přesně na `center.z`.
14. Volume Select se znovu nastaví jako aktivní modifier.

Původní face selection tedy slouží jen k počátečnímu fitu gizma. Po dokončení operace už Volume Select na této selection není závislý.

Pokud operace po vyčištění source selection selže, nástroj musí původní selection obnovit a nesmí hlásit falešný úspěch.

## 8. Volume Select / Material pair rules

Spravovaná dvojice je definována jednoznačně:

`Material modifier` je přímo nad svým `Volume Select` modifierem.

Refresh seznamu může doplnit chybějící Material modifier, ale nesmí měnit Material ID existujících Material modifierů.

Aktivace položky v seznamu aktivuje konkrétní Volume Select. Pokud je ve stacku aktivní jeho párový Material modifier, seznam může stejnou dvojici také zvýraznit.

## 9. Material names

Každé ID má editovatelný významový název uložený v persistentním INI nastavení nástroje.

Název nemění číselné ID ani stack logiku.

Při vytvoření pomocného 12-slot Multi/Sub-Object materiálu se aktuální názvy z UI použijí také jako názvy jeho submateriálů/slotů.

## 10. Error handling a bezpečnost

Implementace se řídí `AGENTS.md` a souvisejícími MaxScript pravidly.

- Žádné prázdné `catch()` bloky.
- Neočekávané chyby se nesmí ignorovat.
- Kritický `catch` musí získat chybu přes `getCurrentException()` a reportovat ji.
- Nesmí vzniknout falešný úspěch po částečně provedené operaci.
- Selection, modifier a stack context musí být před zápisem validované.
- Při selhání tvorby Volume Select dvojice se nově přidané modifiery uklidí a případně vyčištěná source selection se obnoví.
- Existující topologie se při běžném Material ID nebo Volume Select workflow nemění.

## 11. MAXScript pravidla

- Funkce používají `function`, nikdy `fn`.
- Function names používají `camelCase`.
- Variable names používají `snake_case`.
- `if` používá `then`, nikdy `if ... do`.
- Identifikátor `modifier` se nepoužívá jako user-defined name.
- Každá funkce má blokový komentář s popisem na prvním řádku.
- Návratový typ funkce musí zůstat konzistentní na všech code paths.
- Nepoužívají se vymyšlené nebo neověřené MAXScript API funkce.
- Existující ověřené Editable Poly / Edit Poly postupy mají přednost před vlastní neověřenou implementací.
- UI eventy pouze routují akce; hlavní processing zůstává v core funkcích.

## 12. Hlavní princip

Horní rollout říká:

**„Tohle je Material ID, se kterým teď chci pracovat.“**

Aktuální 3ds Max kontext potom určuje, jestli kliknutí:

- vybere faces,
- přiřadí ID do vybraných faces,
- změní aktivní Material modifier,
- nebo změní Material modifier patřící k aktivnímu Volume Selectu.

Číslo ID je vždy explicitní a pochází pouze z kliknutého Material ID tlačítka.
