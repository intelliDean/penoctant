
## Incremental Quadratic Funding Algorithm

For each project $j$, the funding is defined as:

$$
F_j = \alpha \left( \sum_{i=1}^{n_j} \sqrt{c_{i,j}} \right)^2 + (1 - \alpha) \sum_{i=1}^{n_j} c_{i,j}
$$

Where:
- $c_{i,j}$ is the $i$-th contribution to project $j$,
- $n_j$ is the number of contributions to project $j$,
- $F_{\text{quad}, j} = \alpha \left( \sum_{i=1}^{n_j} \sqrt{c_{i,j}} \right)^2$,
- $F_{\text{linear}, j} = (1 - \alpha) \sum_{i=1}^{n_j} c_{i,j}$.

The total funding across all projects is:

$$
\text{Total Funding} = \sum_{j} F_j = \sum_{j} F_{\text{quad}, j} + \sum_{j} F_{\text{linear}, j}
$$

---

## Quadratic Funding Term Calculation

The quadratic term is defined as:

$$
F_{\text{quad}, j} = \alpha \left( \sum_{i=1}^{n_j} \sqrt{c_{i,j}} \right)^2
$$

### Explanation of Calculation:
1. **Sum of Square Roots**:
   - The sum of square roots $S_j = \sum_{i=1}^{n_j} \sqrt{c_{i,j}}$ ensures that smaller contributions have a disproportionately larger effect compared to larger contributions. This promotes fairness and encourages broader participation.

2. **Quadratic Amplification**:
   - Squaring the sum of square roots $S_j^2$ amplifies the collective contributions, emphasizing the total participation rather than the size of individual contributions.

3. **Scaling with $\alpha$**:
   - The parameter $\alpha$ determines the weight of the quadratic term in the total funding calculation. Larger values of $\alpha$ prioritize the quadratic term, making the system more democratic, while smaller values of $\alpha$ reduce its influence, balancing fairness and efficiency.

### Incremental Update:
When a new contribution $c_{\text{new}, j}$ is added, the quadratic term is updated incrementally as:

$$
F_{\text{quad}, j}' = \alpha \left( S_j^2 + 2 S_j \sqrt{c_{\text{new}, j}} + c_{\text{new}, j} \right)
$$

**Why This Works**:
- The formula expands $\left( S_j + \sqrt{c_{\text{new}, j}} \right)^2$ into:
  $\left( S_j + \sqrt{c_{\text{new}, j}} \right)^2 = S_j^2 + 2 S_j \sqrt{c_{\text{new}, j}} + c_{\text{new}, j}$
- By only updating $S_j$ and adding the new contribution's effects incrementally, the recalculation avoids recomputing the entire sum of square roots for all prior contributions.

This ensures correctness, as the updated value matches a full recomputation, and soundness, as the operation is efficient and scales well with the number of contributions.

---

## Incremental Update Rules

### Update State for Project $j$:
1. Update the sum of square roots:
   $S_j' = S_j + \sqrt{c_{\text{new}, j}}$

2. Update the total sum of contributions:
   $\text{Sum}_j' = \text{Sum}_j + c_{\text{new}, j}$

3. Update the quadratic funding term:
   $F_{\text{quad}, j}' = \alpha \left( S_j^2 + 2 S_j \sqrt{c_{\text{new}, j}} + c_{\text{new}, j} \right)$

4. Update the linear funding term:
   $F_{\text{linear}, j}' = (1 - \alpha) \text{Sum}_j'$

### Update Global Aggregated State:
1. Update the quadratic sum:
   $S_{\text{quad}, i}'$ = $\text{Sum}_i$ - $F_{\text{quad}, j}$ + $F_{\text{quad}, j}'$

2. Update the linear sum:
   $\text{Linear\_Sum}' = \text{Linear\_Sum} - F_{\text{linear}, j} + F_{\text{linear}, j}'$

3. Update the total funding:
   $\text{Total Funding}' = \text{Quad\_Sum}' + \text{Linear\_Sum}'$

---

## Correctness Proof

1. **Per-Project Update**:
   - The updates to $S_j$, $\text{Sum}_j$, $F_{\text{quad}, j}$, and $F_{\text{linear}, j}$ are derived directly from the definition of $F_j$. These updates maintain consistency with the original formula.

2. **Global Aggregation**:
   - Changes in $F_{\text{quad}, j}$ and $F_{\text{linear}, j}$ are correctly propagated to the global state variables ($\text{Quad\_Sum}$, $\text{Linear\_Sum}$, and $\text{Total Funding}$).

3. **Efficiency**:
   - Incremental updates avoid recomputation of $\sum_{i=1}^{n_j} \sqrt{c_{i,j}}$ and $\sum_{i=1}^{n_j} c_{i,j}$ for all projects, ensuring efficient updates.

---

## Soundness

The incremental update algorithm adheres to the mathematical definitions and maintains state consistency, even as new contributions are added. This ensures the results are:
- **Accurate**: Outputs match a full recalculation.
- **Efficient**: Updates scale with the number of new contributions, not the total number of contributions.

---

## Optimal Alpha Calculation for 1:1 Shares-to-Assets Ratio

### Objective
Calculate the optimal alpha parameter that ensures total funding equals total available assets, maintaining a 1:1 shares-to-assets ratio.

### Mathematical Formulation

Given:
- Total funding formula: $F_{total} = \alpha \cdot \sum_j S_j^2 + (1-\alpha) \cdot \sum_j \text{Sum}_j$
- Total available assets: $A_{total} = \text{UserDeposits} + \text{MatchingPool}$
- Where $S_j = \sum_i \sqrt{c_{i,j}}$ (sum of square roots for project j)
- And $\text{Sum}_j = \sum_i c_{i,j}$ (sum of contributions for project j)

We want to find $\alpha$ such that:
$$F_{total} = A_{total}$$

### Solving for Optimal Alpha

Starting with the equation:
$$\alpha \cdot \sum_j S_j^2 + (1-\alpha) \cdot \sum_j \text{Sum}_j = \text{UserDeposits} + \text{MatchingPool}$$

Expanding:
$$\alpha \cdot \sum_j S_j^2 + \sum_j \text{Sum}_j - \alpha \cdot \sum_j \text{Sum}_j = A_{total}$$

Rearranging:
$$\alpha \cdot (\sum_j S_j^2 - \sum_j \text{Sum}_j) = A_{total} - \sum_j \text{Sum}_j$$

Therefore:
$$\alpha = \frac{A_{total} - \sum_j \text{Sum}_j}{\sum_j S_j^2 - \sum_j \text{Sum}_j}$$

### Implementation Considerations

1. **Edge Case: No Quadratic Advantage**
   - If $\sum_j S_j^2 \leq \sum_j \text{Sum}_j$, set $\alpha = 0$ (pure linear funding)

2. **Edge Case: Insufficient Assets**
   - If $A_{total} \leq \sum_j \text{Sum}_j$, set $\alpha = 0$ (not enough for even linear funding)

3. **Edge Case: Excess Assets**
   - If $A_{total} - \sum_j \text{Sum}_j \geq \sum_j S_j^2 - \sum_j \text{Sum}_j$, set $\alpha = 1$ (full quadratic funding)

### Use Cases

1. **Fixed Matching Pool**: An admin has a fixed budget for matching funds and wants to maximize quadratic funding benefits while ensuring all funds are distributed

2. **Dynamic Allocation**: As voting progresses, the optimal alpha can be recalculated to adjust the funding formula based on actual participation

3. **Budget Constraints**: Ensures that the total shares minted exactly match the available assets, preventing over-allocation or under-utilization

Let me know if additional clarifications or examples are needed.

