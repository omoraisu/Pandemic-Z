# Zombie Apocalypse
Coursework from University of Hertfordshire

## INTRODUCTION
Zombies. Mystic, mindless and painless creatures with an impressive appetite over human flesh. They’re said to be created from corpses of human beings that are supposedly reanimated by the hand of witchcraft.
A model was designed, by using Netlogo (a simulation software) to test what would happen if a Zombie apocalypse took place, this is, which side would thrive after all? Humans or Zombies?
When bitten, the human being gets infected, turning into a zombie. The human beings are able to fight back. What is going to happen? Let’s see.

## Task
Develop an agent-based model to explore the potential outcomes of a Zombiism epidemic.

## Description

### Agents
The agents in the model are humans and zombies, however, humans turn into zombies if they encounter a zombie and get bitten.
Zombies are reﬂex agents that always attack when confronted by a human. Zombies
wander away from their initial start position moving in random directions until they find themselves co-located with a human.
Humans are rational agents that make decisions based on their immediate environment and the actions they can take at that moment. They should have the ability to see zombies around them using a NetLogo primitive such as in-radius or in-cone.

### Interactions
Humans and zombies interact when they are co-located. Each interaction is deﬁned as occurring between a single zombie and a single human.
Humans and zombies see and recognise each other (zombies do not bite zombies etc.). If a zombie wins a ﬁght, it bites the human, and the human turns into a zombie. On the other hand, the human may ﬂee from the zombie or ﬁght and kill the zombie to avoid being infected.

### Variables
It should be possible to vary the initial number of zombies and humans; this will aﬀect the outcome.

### Outcomes
To ensure your model is not deterministic, you should add some randomness.
The probability of a human killing a zombie is one example.
This could be based on a variable called ‘aggression’ or ‘bravery’, for instance. What would be the outcome of setting bravery very low? (the probability of killing a zombie is small). Would the human population survive (longer, at all) if they were cowardly and more likely to run away from zombies?

### Output
You should provide feedback on the progress of your model – by adding suitable plots, monitors or text output, for example. It should be possible to see different outcomes from varying the initial conditions.

### Schedule
Time is an essential aspect of the model, and you should run each simulation for the same amount of ticks.

## Contact me!

For more information about this project, please email me at mgrosmaninho@hotmail.com
