# RoboticsPortfolio
2026 portfolio — built on the [Strata](https://html5up.net/strata) theme by HTML5 UP (CC BY 3.0; keep the footer credit).

## Where to edit
| What | File |
|---|---|
| Name, title, school (left sidebar) | the `<header id="header">` block at the top of **every** `.html` file |
| About, project cards, experience, skills, contact | `index.html` (search for `TODO`) |
| Personal statement + life timeline | `about.html` (your writing notes are kept as comments) |
| Project detail pages | copy `project-template.html` → e.g. `arm.html`, then point that card's links at it |
| Resume | replace the PDF in `files/` (if the filename changes, update it in `Resume.html`) |
| Achievements & activities | `other.html` |
| Footer links (GitHub, LinkedIn, email) | the `<footer>` block in every `.html` file |
| Colors / fonts / spacing | `assets/css/custom.css` (overrides `main.css`) |
| Photo | put a square image in `images/` and update the `avatar` `<img>` + favicon `<link rel="icon">` |
| Style examples (buttons, tables, forms) | open `elements-reference.html` locally |

Put project media in `images/projects/<project-name>/`. Keep videos as short `.webm`/`.mp4` clips (a few MB) — GitHub warns at 50 MB per file.

## Preview locally
Open `index.html` in a browser, or run `python -m http.server` here and go to http://localhost:8000.
