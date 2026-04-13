# Automotive Material Recycling (AMR)

This repository contains a MATLAB Automotive Material Recycling (AMR) module for estimating recycling cost and greenhouse gas (GHG) emission data for retired automotive lithium-ion batteries in China. The current module covers 337 prefecture-level cities, 6 battery chemistries, and annual model years from 2020 to 2060.

This README documents only the AMR module contained in this folder. It does not describe a complete network optimization workflow.

## Citation

Use of this code should cite the associated Scientific Data article:

Li, Haoyang, Hao, Han, Sun, Xin, Dou, Hao, Mai, Lang, Kang, Tingyuan, Liu, Boyu, Liu, Zongwei, and Zhao, Fuquan. A high-resolution dataset on costs and greenhouse gas emissions of battery recycling in China. Scientific Data, 2026. https://doi.org/10.1038/s41597-026-07577-6

The RIS citation file is provided as `10.1038_s41597-026-07577-6-citation.ris`.

## Repository Structure

```text
.
|-- amr.m
|-- main.m
|-- Parameters/
|   `-- Params.mat
|-- 10.1038_s41597-026-07577-6-citation.ris
|-- LICENSE
`-- README.md
```

The MATLAB files use relative paths. Keep `amr.m`, `main.m`, and `Parameters/Params.mat` in this structure when running the model.

## Requirements

- MATLAB with support for string file names, `interp1`, `writecell`, and `save(..., '-v7.3')`.
- The cached parameter file `Parameters/Params.mat` included in this repository.

## Quick Start

1. Open MATLAB.
2. Set the current folder to the repository root, where `amr.m` and `main.m` are located.
3. Run the default scenario:

   ```matlab
   amr(1)
   ```

   Scenario index `1` is the business-as-usual baseline.

4. To run another scenario, pass its numeric index:

   ```matlab
   amr(s)
   ```

5. Scenario outputs are generated locally under `Results/` as:

   ```text
   Results/AMRS<s>.mat
   ```

`main.m` is an optional local helper for scenario 1. The core model command is `amr(s)`.

## Research Scope

The current implementation estimates unit recycling cost and unit GHG emissions for retired automotive lithium-ion batteries across cities, years, and battery chemistries. The scope is determined by `amr.m` and the cached parameters loaded at runtime.

The hard-coded global settings in `amr.m` are:

- `city = 337`
- `year0 = 2020`
- `year1 = 2060`
- `type = 6`
- `exr = 7.0467`

The modeled battery chemistries are:

```text
LFP, LMO, NCM-L, NCM-M, NCM-H, NCA
```

The process inventory, factor costs, grid emission factors, scenario assumptions, and battery retirement data are loaded from `Parameters/Params.mat`.

## Scenario Index

`amr(s)` selects one scenario by numeric index:

| Index | Code | Scenario name |
| --- | --- | --- |
| 1 | BAU | Business as usual |
| 2 | LLP | Low lithium price |
| 3 | HLP | High lithium price |
| 4 | LNP | Low nickel price |
| 5 | HNP | High nickel price |
| 6 | LCP | Low cobalt price |
| 7 | HCP | High cobalt price |
| 8 | CBC | Conservative battery collection |
| 9 | ABC | Aggressive battery collection |
| 10 | LLR | Low learning rate |
| 11 | HLR | High learning rate |
| 12 | CGT | Conservative grid transition |
| 13 | AGT | Aggressive grid transition |

`CGT` and `AGT` represent conservative and aggressive grid decarbonization pathways, respectively.

## Model Workflow

`amr(s)` is the core AMR function. It performs the following operations:

1. Load cached model parameters from `Parameters/Params.mat`.
2. Read scenario-specific discount factors, prices, collection-rate assumptions, learning rates, and the grid decarbonization factor.
3. Convert retired battery data to retired battery volume by city, year, and chemistry.
4. Construct the collection-rate trajectory and cumulative retired battery volumes used for learning.
5. Compute fixed costs, variable production costs, fixed cost of production, and carbon emission terms.
6. Save the scenario output to `Results/AMRS<s>.mat`.

## Learning Curve Implementation

The learning curve is based on cumulative collected retired battery volume. In `amr.m`, LFP uses its own cumulative volume, while the other five chemistries share the cumulative volume of non-LFP batteries.

The learning factors should be interpreted as changes in unit intensities or activity requirements, not as direct changes in market prices. In the current implementation, learning is applied to model terms built from learned input or activity intensities, while market prices and local factor prices are still taken from the scenario and parameter cache.

The three learning-rate entries selected by each scenario are mapped as follows:

| Learning rate | Affected terms in `amr.m` | Notes |
| --- | --- | --- |
| `lr(1)` | `Land`, `RM`, `Elec`, `Gas`, `Water`, `Steam`, `SW`, `WD`, `RD`, `PC`, `UM`, `WT` | `LD` changes through annualized land cost; `UT` changes through `Elec + Gas + Water + Steam`; `WD` changes through `SW + WW`, where `WW = Water * 0.3`. |
| `lr(2)` | `ISBL`, `OSBL` | `DE`, `X`, `PT`, `CI`, `MT`, and `IS` change indirectly through `ISBL` and `OSBL`. |
| `lr(3)` | `LB` | `GA` changes indirectly because `GA = 0.65 * LB`. |

Utilities-related terms (`Elec`, `Gas`, `Water`, and `Steam`), waste-related terms (`SW` and `WD`), and emission terms (`PC`, `UM`, and `WT`) are all updated through learned input or activity intensities in the current code. Do not interpret the current implementation as applying learning only to costs.

## Collection Rate and Grid Decarbonization

The collection rate is modeled as a Gompertz-type sigmoidal trajectory using `crmin = 0.20`, `crmax = 1`, `cr1 = 0.25`, `t0 = 2020`, `t1 = 2023`, and the scenario-specific `cr2`, which represents the collection rate by 2035.

Grid emission factors are interpolated annually in the cached parameters and then adjusted by the scenario-specific grid decarbonization factor `fgd`.

## Outputs

`amr(s)` writes a detailed MATLAB output file for scenario `s`:

```text
Results/AMRS<s>.mat
```

The file is saved with MATLAB `-v7.3` format. The saved arrays are organized in MATLAB as:

```text
city x year x battery chemistry
```

For the current settings, this corresponds to:

```text
337 x 41 x 6
```

The `save(...)` call in `amr.m` writes exactly the following variables:

| Variable | Description |
| --- | --- |
| `RC` | Total unit recycling cost, calculated as `PT + LD + RM + UT + WD + LB + MT + IS + RD + GA`. |
| `CI` | Capital investment corresponding to annualized plant and land terms, calculated as `PT / DR + LD / fdr`. |
| `PT` | Annualized plant-related cost from ISBL, OSBL, design and engineering, and contingency. |
| `LD` | Annualized land cost. |
| `BT` | Battery-related cost term calculated from lithium, nickel, and cobalt discount factors and prices. `BT` is saved separately but excluded from `RC`. |
| `RM` | Raw material cost for process inputs. |
| `UT` | Utility cost, including electricity, gas, water, and steam terms in the code. |
| `WD` | Waste disposal cost, including solid waste and wastewater-related terms. |
| `LB` | Labor cost. |
| `MT` | Maintenance cost, calculated as `0.05 * ISBL`. |
| `IS` | Insurance cost, calculated as `0.01 * (ISBL + OSBL)`. |
| `OH` | Corporate overhead charges, calculated as `RD + GA`. |
| `RD` | Research and development cost, calculated from revenue and `lr(1)`. |
| `GA` | General and administrative cost, calculated as `0.65 * LB`. |
| `RV` | Revenue from recovered products. |
| `RE` | Total unit recycling GHG emissions, calculated as `PC + UM + WT`. |
| `PC` | Process emissions. |
| `UM` | Upstream material emissions. |
| `WT` | Waste treatment emissions. |
| `PM` | Equivalent GHG emissions of recovered main products, calculated from primary-source production emission factors for the corresponding recovered outputs. |
| `DF` | GHG emission allocation share for recovered main products based on the economic value method. |

`BT` is intentionally not included in `RC`. In the current code, `RC` includes only plant-related annualized cost, land, raw materials, utilities, waste disposal, labor, maintenance, insurance, R&D, and G&A:

```matlab
RC = PT + LD + RM + UT + WD + LB + MT + IS + RD + GA;
```

## Accounting Components

Cost components are defined as follows:

| Component | Definition |
| --- | --- |
| `ALL` | Total unit recycling cost, defined as the sum of all cost components included in `RC`. |
| `Plant` | Annualized cost of recycling facilities, including process equipment and supporting infrastructure. |
| `Land` | Annualized cost of industrial land occupied by recycling facilities. |
| `Labor` | Cost of workforce required for plant operation. |
| `Maintenance` | Cost of routine maintenance and upkeep of equipment and facilities. |
| `Insurance` | Cost of insurance associated with plant operation. |
| `R&D` | Cost allocated to research and development activities. |
| `G&A` | Cost of general and administrative functions associated with plant operation. |
| `Raw materials` | Cost of chemical inputs required for material recovery; this excludes `BT`. |
| `Utilities` | Cost of electricity, natural gas, water, and steam terms represented in the code. |
| `Waste disposal` | Cost of waste treatment and disposal represented by `WD`. |

GHG components are defined as follows:

| Component | Definition |
| --- | --- |
| `ALL` | Total unit GHG emissions, defined as `RE = PC + UM + WT`. |
| `Processing` | Direct or on-site processing-related emissions represented by `PC`. |
| `Upstream materials` | Upstream emissions associated with process material inputs represented by `UM`. |
| `Waste treatment` | Emissions from waste treatment represented by `WT`. |

## Important Notes

- `amr(s)` is the core model run command. It writes `Results/AMRS<s>.mat`.
- `amr(1)` runs the business-as-usual default scenario.
- `Results/AMRS<s>.mat` is overwritten when the same scenario `s` is rerun.
- The MATLAB model runs annual years from 2020 to 2060.
- `Parameters/Params.mat` is required for standard public use of this repository.
- `cr2` should remain within a valid range between `crmin` and `crmax` to avoid invalid logarithmic operations during collection-rate calibration.
- The current learning-rate allocation reflects the current modeling design and is not intended as a universal empirical rule for all battery recycling systems.
- This folder contains the AMR calculation. It should not be described as a complete network optimization repository unless additional optimization scripts are added.

## Reproducibility Checklist

Before using or reporting results, confirm that:

- MATLAB is running from the repository root.
- `Parameters/Params.mat` is present.
- The intended scenario index `s` matches the intended scenario in the scenario table.
- The intended `Results/AMRS<s>.mat` file was generated after the latest model run.
- The associated Scientific Data article is cited when using this code.
