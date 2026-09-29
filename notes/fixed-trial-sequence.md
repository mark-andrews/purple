# The fixed trial sequence in the behavioural task

In the behavioural task a single fixed pseudo-random sequence was used for all participants.
This ensures that differences between participants and groups are not due to differences in stimuli or order.
The cost is that stimulus identity, position and sequential context are the same for everyone, so they are not varied across participants, and some effects of the stimuli cannot be separated from effects of the particular items used.
This note records what the sequence was, its benefits and costs, and how the costs are dealt with in the analysis.

## What the sequence was

This was established from the data on 28 September 2026 (adult data, 47 participants).

The task used one sequence of 50 trials, repeated identically as each of the four blocks.
At every block and trial position, every participant saw exactly the same pair of numerosities (agreement 1.0 in all 47 participants, and between all four blocks).
The sequence contains 45 distinct pairs, most of them shown about four times per block, with numerosities between 40 and 59 dots and ratios (larger over smaller) from about 1.02 to 1.39.
Each pair always appears at the same positions and after the same preceding pair.

Two consequences were found before the sequence itself was identified.
The first trial of every block is the same pair, 47 against 51 dots, a hard ratio, and it also has a very different ERP from other trials, presumably because it follows a break and has no preceding trial (at POz at 253 ms, -2.2 against 5.9 uV).
Consecutive trials' ratios are correlated, at about 0.16 in every participant.

Within the sequence, ratio is not correlated with position (r = -0.03) or with block (r = 0.002).

The reason for using a fixed sequence was not documented, and the most likely mechanism is a fixed random seed in the experiment code.
It may have been a deliberate design choice or not.
For the analysis and its reporting this does not matter, since the consequences are the same either way.
Still to be checked in the experiment code (`mark-andrews/adak`): how the sequence and the dot arrays were generated, and whether the dot images themselves were fixed and can be regenerated exactly.

The child data, checked on 29 September 2026, also used one fixed sequence, but not the adults' one.
Every one of the 53 children saw the same 30 dot trials in the same order, repeated identically as each of three blocks (agreement 1.0 in every child).
The sequence has 29 distinct pairs, with ratios of larger to smaller from 1.02 to 1.45, and only 7 of those pairs are also among the adults' 45.
The first trial of every child block is the same pair, 47 against 59 dots, so the first-of-block problem found in the adult data should be checked for in the child data too.

## Benefits

- Differences between participants cannot come from differences in which stimuli they saw or in what order. This matters most for the individual-differences questions, such as how the ERP relates to ANS acuity, and a fixed order is a common recommendation in individual-differences research for exactly this reason.
- Within the child data, differences between children cannot come from the stimuli either. Between adults and children they can, since the two sequences share only 7 pairs, so adult-child comparisons of stimulus effects must allow for the different stimulus sets.
- A single sequence can be checked once for unwanted patterns, such as long runs of one side or one difficulty.
- Repeating the same 50 trials four times allows each stimulus's response to be checked for consistency across repetitions.
- If the dot arrays were generated from a fixed seed, the exact stimuli can probably be regenerated from the code and all their properties measured.

## Costs

- Stimulus identity and numerical ratio cannot be separated by design. Each ratio value belongs to particular stimulus pairs, and anything peculiar to those pairs (dot sizes, total area, spread, density, which side has more, which response they call for) travels with their ratio.
- Sequential context is fixed. Each pair is always preceded by the same pair, so carry-over from the previous trial is the same for everyone and correlated with the current ratio.
- For questions about the effect of ratio, the effective sample size is closer to the number of distinct pairs, 45, than to the number of trials, about 8300. Each pair is measured very precisely (about 180 times across participants), but whether an effect of ratio generalises to other stimuli rests on 45 items. An analysis that treats every trial as independent evidence about ratio overstates its certainty.
- The first trial of each block is a single repeated item with an anomalous ERP.
- Any learning of the repeated sequence would be the same for everyone and cannot be distinguished from other changes over the session.

What is not affected: the population waveforms (the ERP signature), the size and pattern of individual differences between participants, and the relation between accuracy and the waveform, since these rest on comparisons between participants' average responses to the same stimuli.

## How the costs are dealt with

For the analysis of ratio effects:

1. Exclude the first trial of each block.
2. Include the previous trial's ratio as a covariate. This is already in the model (`prevratio=1` in `analysis/rbf_stan/fit_rbf_multilevel.R`).
3. Treat stimulus pairs as a random factor crossed with participants (Clark, 1973), each pair with its own random deviation waveform, so that the ratio effect is judged against the variation between pairs rather than against trial-to-trial noise. This gives honest, wider uncertainty for the ratio effect.
4. Check item-level consistency across the four repeated blocks.

For the full analysis, later:

5. Regenerate the stimuli from the experiment code if possible, and measure each pair's non-numerical properties (numerical difference, total and individual dot area, convex hull, density, side of the larger array).
6. Enter those properties as item-level predictors alongside ratio, so that a ratio effect is claimed only if it survives them, in the manner of Park et al. (2016). With 45 items only a few such properties can be included at once, and properties strongly correlated with ratio cannot be fully separated from it.
7. Possibly add further sequential covariates, such as the previous trial's accuracy or response.

For future data collection, the sequence should be randomised per participant, or several counterbalanced sequences used, and the choice documented.

## How it should be reported

State plainly that a single fixed pseudo-random sequence was used for all participants, with its benefit for between-participant and between-group comparisons and its cost for stimulus effects, and describe the analysis that addresses the cost.
Claims about ratio should be framed at the level of the stimuli used, and should not be generalised beyond them, or be taken to exclude item-specific properties, until steps 5 and 6 have been done.
Reviewers may still treat it as a design limitation, and it is one, but a disclosed limitation with an appropriate analysis is far easier to defend than an undisclosed one.

## References

Clark, H. H. (1973). The language-as-fixed-effect fallacy: A critique of language statistics in psychological research. Journal of Verbal Learning and Verbal Behavior, 12(4), 335–359. https://doi.org/10.1016/S0022-5371(73)80014-3

Park, J., Dewind, N. K., Woldorff, M. G., & Brannon, E. M. (2016). Rapid and direct encoding of numerosity in the visual stream. Cerebral Cortex, 26(2), 748–763. https://doi.org/10.1093/cercor/bhv017
