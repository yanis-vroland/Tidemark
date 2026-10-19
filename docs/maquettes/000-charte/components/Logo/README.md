Logo de Tidemark (spec 007) : un T dont la barre est une vague, et un point couleur sable au pied de la lettre, la laisse que dépose la marée.

- **Rendu** : tuile `brand`, vague et jambage `on-brand`, point `brand-accent` ; les trois jetons ont la même valeur en clair et en sombre. Trait de 3,2 sur 48, extrémités arrondies, rayon de la tuile 11 sur 48. Version monochrome : tout en `ink` clair (`tidemark-mark-mono.svg`) ; l'icône à thème d'Android ne garde que la forme, recolorée par le système.
- **Où** : icône de l'app, écran de lancement (112 points), état vide de la liste (64 points), README et visuel de partage du dépôt. Nulle part ailleurs.
- **Accessibilité** : décoratif, jamais annoncé par le lecteur d'écran ; le nom s'écrit à côté en `display` quand il doit être lu.
- **Source** : une seule géométrie, dans `tool/generate_brand.py`, qui écrit les SVG de `../../logo/`, les icônes et l'écran de lancement ; l'app la redessine dans `TidemarkLogo` avec les mêmes coordonnées. Ne jamais redessiner le symbole à la main.
- **À éviter** : changer la couleur de la tuile avec le thème, poser le logo sur un fond `tide` (il s'y fond), l'animer.
