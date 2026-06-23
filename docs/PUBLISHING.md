# Publicacion en GitHub

El repo ya esta listo para publicarse:

- Branch: `main`
- Commit inicial creado
- CI configurado en `.github/workflows/ci.yml`
- GitHub Pages configurado en `.github/workflows/pages.yml`
- Sitio estatico en `docs/index.html`

## 1. Login

```bash
gh auth login
```

Elige:

- GitHub.com
- HTTPS
- Authenticate Git with GitHub credentials: yes
- Login with a web browser

## 2. Crear repo y hacer push

Desde la raiz del repo:

```bash
gh repo create Clases --public --source=. --remote=origin --push
```

Si prefieres privado:

```bash
gh repo create Clases --private --source=. --remote=origin --push
```

## 3. GitHub Pages

El workflow `Docs` publica la carpeta `docs`.

Despues del primer push, ve a:

```text
https://github.com/<usuario>/Clases/actions
```

Abre el workflow `Docs`. Cuando termine, la URL aparece como deployment `github-pages`.

Normalmente sera:

```text
https://<usuario>.github.io/Clases/
```

## 4. Verificar

```bash
gh repo view --web
```

Y revisa:

- Actions -> CI
- Actions -> Docs
- Settings -> Pages

## 5. Publicar versiones

Cuando quieras cortar release:

```bash
git tag v0.1.0
git push origin v0.1.0
gh release create v0.1.0 --title "Clases v0.1.0" --notes "Initial release"
```
