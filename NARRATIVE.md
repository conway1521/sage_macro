# The whole situation, in plain English

A single document for you (and a non-specialist reader) that tells the entire SAGE-Bewley story: what the model is, what every parameter means, how each one was set and what evidence pinned it, what the model produces, and where it is going. Everything below is true of the code and the papers as they sit in the repository today.

## 1. The project in one paragraph

We are turning a 2020 master's thesis into a small calibrated piece of macroeconomic machinery for the wellbeing-economics community. The machinery is a heterogeneous-agent model, meaning a model with many different households who differ in wealth, productivity, and education, rather than one identical representative person. The novelty is that wellbeing in the model has separate dimensions, material gain and social cohesion, instead of one single index, and one of those dimensions, the social one, has a feedback loop: the value of giving time to society rises with how much time others give. From that model we have written two short papers: one on what a familiar pro-work policy does when you look at wellbeing as multidimensional, and one on what gives rise to coordination and tipping when you do it honestly. The whole thing runs in Julia, it is fast enough to be interactive, and there is an open lecture site that walks a reader through it.

## 2. The model in plain English

### Who is in it

A large population of households. Each household has assets (its wealth, which it carries from period to period and saves out of), a productivity level that randomly goes up and down (so it earns more in some periods than others), and a permanent education level. The two education levels are simply lower and higher, and they matter because lower-education households face worse working conditions and value belonging slightly less, both of which we calibrate to data on real differences by education.

### What they do

Every period, a household decides three things: how much to consume now, how much to save for later, and how much of its time to spend on paid work versus contributing to social life. Time not spent on paid work is the contribution. The household cannot borrow against future income and cannot insure against the productivity ups and downs, which is the standard Bewley setup: households self-insure by holding savings, and the wealthier they are the smoother their consumption.

### What "wellbeing" means in the model

Two separate things. The material dimension is the familiar one: more consumption is better, more effort hurts (in a calibrated way). The social dimension is the new thing: the value a household gets from how strong social life is around it. We carry two layers of richness in the social side. In the simpler version of the model the social dimension is just a count, the average non-work time across the population, and households value it more if they have higher belonging tastes. In the richer version, used in the second paper, social life is participation in associations, clubs, and standing commitments, which is a discrete yes-or-no choice with a minimum meaningful time commitment, and the value of joining rises with how many others join. That richer version is what the data on French participation actually measure.

### The crucial design choice

Decision utility (what households maximise) is deliberately not the same as experienced wellbeing (how we judge welfare). The act of contributing enters what people maximise; the enjoyment of the resulting social fabric enters how we judge their wellbeing. This split lines up with what the empirical wellbeing literature has been saying for two decades, that subjective life satisfaction is not the same thing as the utility implicit in choice. It is also what lets a one-number consumption planner and a multidimensional wellbeing planner disagree about a policy.

## 3. Every parameter, what it is, and how it was set

Each entry: what it is in plain English, what value we use, and how that value was pinned. Anything not sourced is openly swept and reported with sensitivity.

### Preferences (how households weigh consumption, effort, and time)

**Risk aversion (gamma = 2).** How much households dislike the ups and downs of consumption: a higher number means they care more about smoothness. We use 2 because the largest meta-analysis of this number, which surveys 169 studies, finds an average of roughly 2 after correcting for publication bias. This is the same value the workhorse heterogeneous-agent literature uses.

**Labour-supply responsiveness (Frisch elasticity = 0.5, so the inverse-Frisch parameter psi = 2).** How readily a household changes hours when the return to work changes: a higher elasticity means a bigger response. We use 0.5, the quasi-experimental consensus that Chetty, Guren, Manoli, and Weber synthesised in their 2011 review of the field. The thesis carried a value of 4, eight times this, and it was the indefensible setting that produced the dramatic tipping result we have now retracted.

**Effort disutility scale (phi = 14.0).** This is the only preference dial we calibrate, because it has no standard value. We tune it so that the model's split between paid work and unpaid time matches the French time-use survey: paid work averages 3 hours 24 minutes a day and unpaid domestic and associative work 3 hours 1 minute, a paid share of 0.53, and at phi = 14 the model delivers 0.53.

**Patience (beta = 0.96, annual).** How much households discount future consumption: 0.96 is the standard value of the Aiyagari tradition, an annual interpretation. The thesis used 0.99, which combined with the interest rate below to make the wealth distribution unstable in the corrected model; we fixed both.

### The market (what the household is operating in)

**Interest rate (R = 1.02, so 2 percent real per year).** The rate at which savings grow. We use a long-run real rate near two percent, the central estimate from the long-running Holston-Laubach-Williams work on the natural rate.

**Productivity process (persistence rho = 0.9, dispersion eta = 0.1).** How a household's productivity bounces over time: 0.9 persistence means a productive year is followed mostly by another productive year, 0.1 dispersion means the bounces are not enormous. Both are inside the published ranges for annual processes surveyed by Heathcote, Storesletten, and Violante. We can do better than two states; a richer five-by-three process is built and validated.

### The social dimension (the new bit)

**Agency by education (alpha_low = 0.765, alpha_high = 0.911).** The fraction of effort that becomes income. The lower number for the lower-education group captures real differences in labour-market security, health, and skills as the OECD Better Life indicators measure them. This is the thesis's construction from those indicators for France.

**Belonging taste by education (B_low = 0.80, B_high = 0.94).** How much a household values the social fabric. Again from the OECD Better Life support-network items, by education. Higher-education people report stronger support networks.

**Cohesion weight (Lambda = 0.876).** The relative weight of the social dimension in wellbeing. This is the thesis value, derived from the OECD dimension rankings. It is the one preference number that is not yet from a panel estimation, and the design note for estimating it from life-satisfaction data is written; this is the natural collaboration object for a WISE partner.

**Interaction strength (kappa = 10) and taste dispersion (sigma_m = 0.5).** These two are the participation model's new dials, and they are calibrated jointly to two French facts: roughly a third of adults participate in associative life, and participation rises steeply with education (about a quarter of the less-educated, about a half of the more-educated, in the INSEE thirty-year series). The model at kappa = 10 and sigma_m = 0.5 delivers a stable equilibrium with the lower-education group at 26.5 percent and the higher-education group at 47.6 percent, against targets of 25 and 45.

**Private payoff share (omega = 0.30).** Of the value of joining associative life, how much is the warm-glow that does not depend on others (volunteering even where almost no one volunteers) versus how much depends on others. There is no clean point estimate, so we sweep this from 0.15 to 0.50 and report how every result depends on it.

**Participation lump (qbar = 0.10).** How much time joining associative life costs: a tenth of committed time, the order of magnitude that time-use surveys report for participants' actual social and volunteer time.

### Genuinely swept (declared as such)

**Social-multiplier strength in the smooth model (kappa, separately).** No clean estimate; reported as a sweep.

**Homophily weight (h between 0 and 1).** How much belonging comes from one's own group versus the whole economy. No estimate; swept.

### The validation: untargeted moments

The honest test of any calibration is what the model matches that you did not aim at. The calibrated model produces a hand-to-mouth share of 0.33 (the European data is around 0.30, the standard literature value) and a wealth Gini of 0.55 (the French data is around 0.68, standard models of this class manage 0.38). Both come out without anyone telling the model to hit them. The one moment we do not yet match is the income Gini: at two productivity states it is too low; the architecture for fixing it (education cells with persistent and transitory shocks) is built and a recommended configuration is set aside for the next paper.

## 4. What the model produces, in plain English

### From the first paper (the S paper)

The model takes a recognisable policy, a 20 percent make-work-pay subsidy financed by a flat per-head tax (the same money goes out as comes in, so the government is not running a deficit), and shows two things at once:

The first is the aggregate result: total consumption rises by about 5.5 percent and the social fabric shrinks by about 4.7 percent, because the subsidy makes work more attractive and time given to society less attractive. The familiar trade-off.

The second is the result that single-number evaluation cannot see: the incidence. Because the financing is a flat tax on everyone but the subsidy only matters for people who earn labour income, the lower-income group loses on the material side outright (their tax bill is bigger than their subsidy), and they lose on the social side too. The higher-income group's material gain rises, and they also lose on the social side. The "aggregate" consumption gain that the headline number reports is entirely produced by the better-off group. The lower-income group loses on every dimension at once.

The paper also reports a discipline result, with equal prominence, because we found it ourselves before a referee did: a smoother version of social tipping that we previously claimed simply cannot survive the published labour-supply elasticity. At the consensus number there is no fold in the equilibrium map at any feedback strength up to fifteen times the old window. We say so explicitly and explain why: tipping in the smooth model required households to reallocate their time eight times more readily than the evidence allows.

### From the second paper (the S+A paper, on agency and participation)

This paper takes the same engine and adds the discrete participation choice (join an association or do not). It calibrates the participation model to French data and asks four questions.

Why does participation rise with education? The model says half is taste (the OECD indicators show higher-educated people value belonging more) and half is what we call agency-through-wealth: higher agency makes households richer over their lives, and richer households find the time commitment of participation cheaper to bear. Even though their hour of time is more expensive, the income effect wins, which is what the data require, since participation in fact rises with income.

Are coordination traps a real possibility? The model can produce them: two societies at the same fundamentals, one where many people participate and many more therefore want to, one where few do and few are pulled in. But there is a sharp catch: the parameter region that produces traps requires belonging tastes to be concentrated (so many people change behaviour together), while the parameter region that fits the French participation gradient requires tastes to be dispersed (because the gradient itself is evidence of dispersion). The two regions never overlap. The calibrated French economy sits at the boundary of the trap region, not inside it. Close enough to matter, outside in the point estimate.

What does activation policy do here? The financed make-work-pay subsidy, applied to the participation model, collapses participation from 37 percent to 8 percent. The "direct" effect (what happens if every household reconsiders, but holding everyone else's participation fixed) is a fall of 8 points. The "equilibrium" effect (after the feedback loop has worked through) is a fall of 29 points. The ratio, 3.6, is the social amplification: each person who leaves lowers everyone else's reason to stay. The same feedback that could not fold the smooth model amplifies a small policy shock into a large outcome on the discrete margin.

What about a different pro-work policy? Raise the lower-education group's agency to the population mean: empowerment, training, health, labour-market access. Equilibrium participation rises from 37 to 51 percent. Two pro-work policies from the same family: one collapses the social fabric, the other expands it. Subsidising hours raises the price of time; raising agency raises wealth. A single-number evaluation that looks only at output cannot tell these two policies apart on the margin where they differ most.

## 5. The other things in the repository

**A homophily channel.** Belonging can come from one's own group rather than from society as a whole (the bonding versus bridging distinction in the sociological literature). Turning that dial towards own-group-only widens the cohesion gap between education groups and redistributes social wellbeing regressively: the higher-education group gains 9 percent, the lower loses 9 percent. A structural rendering of the claim that bridging social capital is what the disadvantaged can least afford to lose.

**A measured-types population.** Instead of assuming everyone has the same social motive, we let the population be the experimentally measured mix of half conditional cooperators (contribute when others do), a third free riders (contribute only when paid), and a fifth committed givers (contribute regardless), the proportions Fischbacher, Gachter, and Fehr found in laboratory experiments. The model says: committed givers raise everyone's contribution with increasing returns, but under honest settings they cannot flip society.

**A QuantEcon lecture.** A public-facing walkthrough of the model, runnable from the browser, with the financed-subsidy decoupling experiment as its punchline. The executed output now matches the working paper exactly.

**An adversarial review of our own results.** REVIEW.md in the repository is the technical record of the night we stress-tested the model as a hostile referee would, including the retraction of our previous biggest result. Carrying the review in the repository is, on its own, part of the credibility offer.

**A calibration design note for collaboration.** We have one preference parameter (the cohesion weight) that should be estimated from life-satisfaction panels rather than taken from rankings. The note in the vault sets out the regression a partner would already have run, and the deliverable they would get in exchange (counterfactuals in WELLBYs, the wellbeing-adjusted life year that the policy audience already uses).

## 6. What is honestly still open

We have not yet run the lecture's GitHub Pages deploy because it needs a new remote on your account; everything else is on github.com/conway1521/sage_macro. The general-equilibrium close (so prices respond, and the agency wedge has somewhere for the lost income to go) is Paper 3 infrastructure, not a patch. The cohesion weight is the one preference parameter still on a thesis-era source; the estimation design note is the offer to fix it. And the country rows (US, Netherlands, Italy) are placeholders waiting for one row of data each.

## 7. The honest version of why this is worth doing

A model that lets you put a number on the social cost of a policy, calibrated against data the wellbeing-empirics community already collects, is something that community does not currently have. The model is small enough that a careful collaborator can read it in an afternoon, fast enough to be played with in a browser, and built so that whoever brings the data gets the counterfactuals out. The night we stress-tested it and retracted the biggest result is the reason the rest of the claims will hold up.
