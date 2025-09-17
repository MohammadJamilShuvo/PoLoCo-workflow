#!/usr/bin/env python3
"""
workflow_diagram.py
-----------------------------------
Generate workflow diagram for PoLoCo pipeline (Figure 6).
Outputs: workflow_diagram.png + workflow_diagram.svg
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# Define steps
steps = {
    1: ("Preprocessing & QC\n(env: poloco_qc_mapping)", (0, 4)),
    2: ("Mapping & BAM Filtering\n(env: poloco_qc_mapping)", (4, 4)),
    3: ("Coverage Estimation\n(env: poloco_qc_mapping)", (0, 2)),
    4: ("SNP Discovery (ANGSD)\n(env: poloco_angsd)", (4, 2)),
    5: ("QC Visualization\n(env: poloco_angsd)", (8, 2)),
    6: ("Assembly (Draft Genome)\n(env: poloco_assembly)", (0, 0)),
    7: ("Validation\n(env: poloco_assembly)", (4, 0)),
    8: ("Annotation (optional)\n(env: poloco_annotation)", (8, 0))
}

fig, ax = plt.subplots(figsize=(12, 6))
ax.set_xlim(-1, 10)
ax.set_ylim(-1, 6)
ax.axis("off")

# Draw boxes
for step, (label, (x, y)) in steps.items():
    rect = mpatches.FancyBboxPatch(
        (x, y), 3, 1.2, boxstyle="round,pad=0.2",
        fc="lightblue" if step < 6 else "lightgreen" if step < 8 else "lightgrey",
        ec="black"
    )
    ax.add_patch(rect)
    ax.text(x+1.5, y+0.6, label, ha="center", va="center", fontsize=9)

# Draw arrows
def arrow(start, end):
    ax.annotate("",
                xy=(steps[end][1][0], steps[end][1][1]+0.6),
                xytext=(steps[start][1][0]+3, steps[start][1][1]+0.6),
                arrowprops=dict(arrowstyle="->", lw=1.5))

arrow(1, 2)
arrow(2, 4)
arrow(3, 4)
arrow(4, 5)
arrow(6, 7)
arrow(7, 8)

# Vertical links
ax.annotate("", xy=(steps[1][1][0]+1.5, steps[1][1][1]), 
            xytext=(steps[3][1][0]+1.5, steps[3][1][1]+1.2),
            arrowprops=dict(arrowstyle="->", lw=1.5))
ax.annotate("", xy=(steps[6][1][0]+1.5, steps[6][1][1]+1.2), 
            xytext=(steps[3][1][0]+1.5, steps[3][1][1]),
            arrowprops=dict(arrowstyle="->", lw=1.5))

plt.title("PoLoCo Workflow", fontsize=14, weight="bold")
plt.tight_layout()

# Save
plt.savefig("07_plots/workflow_diagram.png", dpi=300)
plt.savefig("07_plots/workflow_diagram.svg")
print("[OK] Workflow diagram saved in 07_plots/")

