---
title: "SAGE, version 2: a summary for readers who do not build models"
author: "Alessandro Conway"
date: "November 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

# What SAGE is

SAGE is a model of households in France, Germany and Italy who earn, save, lose and find jobs, and receive benefits when they are out of work. It differs from most models of this kind in what it counts as doing well. Beside consumption, it carries three further parts of wellbeing that can each be switched on or off: social participation (S), agency and the insecurity of work (A), and the environment people live in (E). Switching a part off gives back the model without it exactly, so each part's contribution can be read on its own. Every parameter is a published estimate, fitted to a named statistic, or a stated normalisation.

Version 2 moves the model from years to quarters. That lets unemployment last as long as it does in the Labour Force Survey, benefits follow each country's rules quarter by quarter until entitlement runs out, and job search respond to benefits within a spell out of work. Households are split into two education groups, with and without a tertiary degree. The environment part works on the quarterly model by type of place (cities, towns and suburbs, rural areas), each with its own access to work and unemployment, while its combination with social participation is still run on the annual version 1, because the quarterly version takes longer than the computers available allow.

# What it gets right

The model is fitted to the share of households living hand to mouth, with almost no cash to fall back on, and to the gap in that share between the two education groups (Household Finance and Consumption Survey, 2021). It then has to reproduce, without being fitted to them, several things economists measure directly.

Spending out of an unexpected windfall is the first. In the model a household spends 53 to 71 per cent of a windfall of one month's income within the year, about a sixth in the following year, and 83 to 92 per cent over five years. Norwegian lottery winners, observed in tax registers, spend about half within the year of winning, about 0.18 the year after and about 0.90 over five years (Fagereng, Holm and Natvik 2021). The timing matches closely, and the first year matches in Italy and is higher in Germany and France.

The response of job search to benefits is the second. I set how sharply search effort reacts on German evidence about longer benefit entitlement. With that one choice, the model's response to the level of benefits falls within the measured range in France, near it in Italy and somewhat above the European average in Germany.

# What it says about wellbeing

The wellbeing account is in points of life satisfaction on the usual 0 to 10 scale, per head of the population and per year.

| points per head and year | France | Germany | Italy |
|---|---|---|---|
| being unemployed, beyond the lost income | -0.068 | -0.029 | -0.074 |
| being inactive, beyond the lost income | -0.007 | -0.017 | -0.007 |
| dread of losing one's job or staying out of work | -0.046 | -0.054 | -0.037 |
| taking part in social life | +0.016 | +0.019 | +0.009 |
| air quality | -0.049 | -0.058 | -0.103 |

Three points stand out. First, the insecurity of work weighs on the population on the same scale as unemployment itself. Dread, the anticipation of a bad change in one's job situation over the coming year, costs 0.04 to 0.05 points per head, from half the cost of unemployment beyond income in Italy to nearly twice it in Germany, because it is felt by the many who might lose their job and not only by the few who do. Among people in work it is worth 0.7 to 1.4 per cent of their consumption. Its size depends on whether people look a year or a quarter ahead, and with a quarter it is about half, so I report both. Second, the cost of being out of work beyond income is lower in Germany, where most jobless households are inactive rather than unemployed, and inactivity costs less in life satisfaction than unemployment. Third, air quality costs about three quarters of what unemployment does in France, twice as much in Germany and more in Italy.

# What it cannot yet do

The model has one kind of wealth, cash and deposits. It therefore cannot represent households who own a house or hold a pension but have little cash, who are from about half of those living hand to mouth in Italy to four fifths in France and are more common among households without a degree. I tried three ways of adding a second, harder to use, kind of wealth, and none placed these households correctly by education. In my view this needs housing modelled with ownership over the life course, which is a project in itself. The model also overstates how much consumption falls when a job is lost, by four to five times the best estimate, and part of that gap is likely the missing housing and pension wealth. Spending out of a windfall is higher than survey answers in France and Germany, although it matches the lottery evidence on actual spending more closely. In rural France the model puts too many households hand to mouth, 0.28 against 0.19 in the survey. Finally, the response of job search to longer entitlement is similar in the three countries, while the studies find it two to three times larger in France and Italy than in Germany.

# What comes next

The model is ready for review as a foundation: its parts switch on and off exactly, its targets are stated, and its limits are known. The next steps are to use it for questions about insecurity and benefits by education group, and in a later version to add housing.

This summary uses data from the Eurosystem Household Finance and Consumption Survey. The full model note (`sage_v2_note.md`) gives the method, the sources and the tests.
