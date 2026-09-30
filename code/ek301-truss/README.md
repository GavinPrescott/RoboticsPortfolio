# EK301 Truss Analyzer & Builder

MATLAB tools I wrote for the Boston University EK301 (Engineering Mechanics: Statics) truss design project, Spring 2026.
Project write-up: [gavinprescott.github.io/RoboticsPortfolio/truss.html](https://gavinprescott.github.io/RoboticsPortfolio/truss.html)

## Files

| File | What it does |
|---|---|
| `truss_builder.m` | Interactive GUI. Click to place joints and members on a snapping grid, set pin/roller/load, and solve. Enforces every project rule live (member length 6–14″, span 26–30″, load position, 120″ material budget, no crossing members, M = 2J − 3) and flags violations in red. Exports a `.mat` file and a paste-ready block for `truss_analysis.m`. |
| `truss_analysis.m` | Solver. Builds the 2J × (M+3) equilibrium matrix from joint coordinates and a connection matrix, solves for all member forces and reactions, predicts buckling with the course's empirical model `P = 37.5·(10/L)²` oz (±10 oz), and reports the critical member, max load, uncertainty, cost, and load-to-cost ratio. Includes three verification trusses (3, 11, and 21 members). |

## Usage

1. Run `truss_builder` in the MATLAB command window, design a truss, and click **SOLVE**.
2. Click **Export .mat** to save the design and print a code block.
3. Paste that block into Section 1 of `truss_analysis.m` and run it for the full member table and plot.

## Cost & buckling parameters

- Cost: $10 per joint + $1 per inch of member
- Buckling: `P_crit = 37.5 · (10 / L)^2` oz, fit uncertainty ±10 oz (from the course lab manual)
