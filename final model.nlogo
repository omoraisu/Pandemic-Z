; Pandemic Z: Optimizing Group Size for Survival in a Resource-Limited Zombie Outbreak

; ----- BREEDS -----
breed [humans human]
breed [zombies zombie]
breed [resources resource]  ; Food, water, supplies as physical entities

; ----- GLOBAL VARIABLES -----
globals [
  day                ; tracks day count for survival metrics
  day-phase          ; 0 = day, 1 = night
  total-survivors    ; count of remaining humans
  total-deaths       ; count of humans who died
  total-infections   ; count of humans who became zombies
  total-conflicts    ; count of times when stress level across humans is high
  zombie-kill-count  ; zombies killed by humans
  resource-scarcity  ; global metric of resource availability (0-100)
  average-hunger     ; track average hunger across all humans

  ; ----- RCT-Specific Globals -----
  intergroup-conflicts ; conflicts between human groups
  cooperation-events   ; successful cooperation instances
  superordinate-active? ; whether a superordinate goal is active
  superordinate-progress ; progress toward superordinate goal

  ; New variables for conflict frequency tracking
  conflict-frequency   ; conflicts per tick (rolling average)
  conflicts-this-tick  ; count of conflicts in current tick
  conflict-history     ; list to store recent conflict counts for averaging
  survival-time        ; ticks since simulation started
  total-conflicts-cumulative ; NEW: total conflicts throughout entire simulation

  ; Group management
  current-resource-pressure ; 0-100, drives RCT behaviors
]

; ----- AGENT PROPERTIES -----
humans-own [
  energy             ; 0-100, decreases over time, needs food/rest
  speed              ; depends on energy level (0.1-1)
  strength           ; affects combat outcomes (1-10)
  state              ; "wandering", "running", "hiding", "fighting", "infected", "corpse"
  vision-range       ; varies with day/night cycle
  hearing-range      ; for zombie detection
  resource-inventory ; food and water carried (0-100)
  hunger-level       ; 0-100, if reaches 100, human dies
  stress-level       ; 0-100, affects decision-making
  trust-level        ; 0-100, affects cooperation
  cooperation-level  ; 0-100, willingness to share/protect others
  infection-timer    ; countdown if infected
  skill-combat       ; 0-100, improves with zombie fights
  skill-gathering    ; 0-100, improves with resource collection

  ; NEW: Rest-related properties
  fatigue-level      ; 0-100, builds up over time and with activity
  rest-timer         ; how long they've been resting/hiding
  hiding-reason      ; "safety", "rest", or "both" - tracks why they're hiding

 ; ----- RCT-Specific Properties -----
  group-loyalty      ; 0-100, affects in-group preference
  out-group-hostility ; 0-100, affects conflict likelihood
  resource-competition ; 0-100, drives competitive behavior
  last-resource-time ; ticks since last successful resource collection
  competitive-state  ; "neutral", "competing", "cooperating", "hostile"
  ally-list          ; list of human IDs considered allies
  enemy-list         ; list of human IDs considered enemies
]

zombies-own [
  health             ; 0-100
  speed              ; typically slower than humans
  strength           ; determines damage to humans
  state              ; "wandering", "chasing", "feeding"
  vision-range       ; typically poor
  hearing-range      ; typically good
  satiation          ; increases when feeding, decreases over time
]

resources-own [
  amount
  contested?         ; whether multiple groups are competing for this resource
  discovery-time     ; when this resource was first discovered
]

patches-own [
  resource-level     ; amount of available resources (0-100)
  is-shelter         ; boolean if patch is shelter
  shelter-quality    ; how good the shelter is (0-100)
  zombie-scent       ; for zombie tracking of humans
  human-scent        ; for zombies to detect humans
  last-visited       ; when patch was last visited by any agent
  territory-marker   ; which group "claims" this area
  conflict-zone?     ; whether this area has seen recent conflicts
]

; ----- SETUP PROCEDURES -----
to setup
  clear-all
  setup-environment
  setup-humans
  setup-zombies
  setup-resources
  initialize-rct-variables
  setup-plots
  reset-ticks
end

; Initialize RCT-specific variables
to initialize-rct-variables
  set intergroup-conflicts 0
  set cooperation-events 0
  set superordinate-active? false
  set superordinate-progress 0
  set current-resource-pressure 50

  ; Initialize conflict tracking variables
  set conflict-frequency 0
  set conflicts-this-tick 0
  set conflict-history []
  set survival-time 0
  set total-conflicts-cumulative 0  ; NEW: Initialize cumulative counter
end

; Create the environment with varied terrain
to setup-environment
  ; Create landscape with various resource levels
  ask patches [
    set resource-level random-float 20  ; Initial resources are sparse
    set is-shelter false
    set zombie-scent 0
    set human-scent 0
    set last-visited 0
    set territory-marker 0
    set conflict-zone? false

    ; Random terrain coloring based on resource levels
    set pcolor scale-color green resource-level 0 100

    ; Add hiding spots with 10% chance
    if random-float 1 < 0.001 [
      set pcolor one-of [black gray]
    ]
  ]

  ; Create some shelters randomly throughout the map
  let shelter-count (count patches) * 0.005  ; 2% of patches are shelters
  ask n-of shelter-count patches [
    set is-shelter true
    set shelter-quality 50 + random 50  ; Varied shelter quality
    set pcolor brown
  ]

  ; Set initial values
  set day 1
  set day-phase 0  ; Start with daytime
  set resource-scarcity 50  ; Medium scarcity to start
end

; Setup initial human population
to setup-humans
  create-humans initial-human-population [
    set shape "person"
    set color green
    set size 1.5
    move-to one-of patches with [not any? humans-here]

    ; Initialize human properties
    set energy 75 + random 25
    set speed 0.5 + random-float 0.5
    set strength 3 + random 7
    set state "wandering"
    set vision-range 5 + random 3
    set hearing-range 3 + random 2
    set resource-inventory 20 + random 30
    set hunger-level 0
    set stress-level 20 + random 20
    set trust-level 50 + random 50
    set cooperation-level 50 + random 50

    ; Skills start relatively low
    set skill-combat 10 + random 20
    set skill-gathering 10 + random 20

    ; NEW: Initialize rest-related properties
    set fatigue-level 0
    set rest-timer 0
    set hiding-reason "none"

    ; Not infected at start
    set infection-timer 0

   initialize-rct-properties
  ]

  set total-survivors count humans
end

; Initialize RCT-specific properties for humans
to initialize-rct-properties
  ; All humans belong to one group
  ; set group-id 1

  ; Set individual competition and cooperation tendencies
  set group-loyalty 60 + random 40
  ;set out-group-hostility 0  ; Not used since we have one group
  set resource-competition 30 + random 40
  set last-resource-time 0
  set competitive-state "neutral"
  set ally-list []
  set enemy-list []

  ; Start with default color (will change based on state)
  set color green
end

; Setup initial zombie population
to setup-zombies
  create-zombies initial-zombie-population [
    set shape "person"
    set color red
    set size 1.5
    move-to one-of patches with [not any? turtles-here]

    ; Initialize zombie properties
    set health 75 + random 25          ; Initial health of zombie
    set speed 0.3 + random-float 0.3   ; Zombies are slower than humans
    set strength 8 + random 4          ; But stronger
    set state "wandering"
    set vision-range 3 + random 2      ; Poor vision
    set hearing-range 6 + random 4     ; Good hearing
    set satiation 0                    ; Start hungry
  ]
end

; Create initial resource patches
to setup-resources
  ; Distribute resources (food, water, medical supplies)
  create-resources initial-resource-count [
    set shape "box"
    set color yellow
    set size 1

    ; Set amount value
    set amount 10 + random 20

    move-to one-of patches with [not any? turtles-here]
  ]
end

; ----- MAIN PROCEDURES -----
to go
  ; Reset conflicts counter for this tick
  set conflicts-this-tick 0
  set survival-time ticks

  ; Update time and environment
  ; update-time
  ; update-resources

  ; Update RCT dynamics
  update-resource-pressure
  update-group-dynamics

  ; Update agents
  ask humans [human-behavior]
  ask zombies [zombie-behavior]
  ; ask corpses [update-corpse]

  ; Handle superordinate goals (zombie threats)
  handle-superordinate-goals

  ; Update conflict frequency tracking (do this AFTER agents act)
  update-conflict-frequency

  ; Update and plot hunger statistics
  update-hunger-stats
  plot-hunger-data
  plot-total-conflicts  ; NEW: Plot cumulative conflicts

  tick
end

; Modified procedure to track conflict frequency AND cumulative total
to update-conflict-frequency
  ; Add current tick's conflicts to cumulative total
  set total-conflicts-cumulative total-conflicts-cumulative + conflicts-this-tick

  ; Add current tick's conflicts to history for rolling average
  set conflict-history lput conflicts-this-tick conflict-history

  ; Keep only last 50 ticks for rolling average
  if length conflict-history > 50 [
    set conflict-history but-first conflict-history
  ]

  ; Calculate rolling average conflict frequency
  if length conflict-history > 0 [
    set conflict-frequency mean conflict-history
  ]

  ; Debug output to see what's happening
  if conflicts-this-tick > 0 [
    print (word "Tick " ticks ": " conflicts-this-tick " conflicts this tick, total conflicts: " total-conflicts-cumulative ", running average: " conflict-frequency)
  ]
end

; NEW procedure to plot total cumulative conflicts
to plot-total-conflicts
  set-current-plot "Total Conflicts Over Time"
  set-current-plot-pen "total-conflicts"
  plotxy survival-time total-conflicts-cumulative
end

; New procedure to calculate average hunger
to update-hunger-stats
  if count humans > 0 [
    set average-hunger mean [hunger-level] of humans
  ]
end

; New procedure to plot the data
to plot-hunger-data
  set-current-plot "Average Hunger Level"
  set-current-plot-pen "hunger"
  plot average-hunger
end

; Fix the update-resource-pressure procedure
to update-resource-pressure
  let total-resources count resources + sum [resource-level] of patches
  let total-humans count humans

  ; Calculate pressure based on resource-to-human ratio
  if total-humans > 0 [
    ; Fixed calculation - when resources are 0, pressure should be 100
    let resource-ratio total-resources / total-humans
    set current-resource-pressure 100 - (resource-ratio * 5)  ; Reduced multiplier for more sensitivity
    set current-resource-pressure max (list 0 (min (list current-resource-pressure 100)))
  ]

  ; Update individual competition levels
  ask humans [
    set resource-competition 0.7 * resource-competition + 0.3 * current-resource-pressure
    set last-resource-time last-resource-time + 1
  ]
end

; Update group dynamics and relationships
to update-group-dynamics
  ask humans [
    ; Increase competition and hostility when resources are scarce
    if current-resource-pressure > 60 [
      set resource-competition min (list (resource-competition + 2) 100)
      ; Reduce cooperation within group when resources are scarce
      set cooperation-level max (list (cooperation-level - 1) 0)
    ]

    ; Increase cooperation when resources are abundant
    if current-resource-pressure < 40 [
      set resource-competition max (list (resource-competition - 1) 0)
      set cooperation-level min (list (cooperation-level + 1) 100)
    ]
  ]
end

; MODIFIED: Handle superordinate goals with reduced effect (Option B)
to handle-superordinate-goals
  ; Activate superordinate goal when zombie density is high
  let zombie-density count zombies / (world-width * world-height)

  if zombie-density > 0.1 and not superordinate-active? [
    set superordinate-active? true
    set superordinate-progress 0

    ; OPTION B: Reduce superordinate goal effect - only 10% reduction instead of 30%
    ask humans [
      set resource-competition resource-competition * 0.8  ; meaning 20% decrease in competition if superordinate is triggered
      set cooperation-level min (list (cooperation-level + 20) 100)
    ]
  ]

  ; Deactivate when zombie threat is low
  if zombie-density < 0.05 and superordinate-active? [
    set superordinate-active? false
  ]
end

; ----- HUMAN BEHAVIOR PROCEDURES -----
to human-behavior

  ; Skip if dead
  if state = "corpse" [update-corpse-state stop]

  ; MODIFIED: Basic metabolism with fatigue
  set energy energy - 0.1
  set hunger-level hunger-level + 0.2
  set fatigue-level fatigue-level + 0.3  ; NEW: Fatigue builds up over time

  ; Activity increases fatigue more
  if state = "running" [set fatigue-level fatigue-level + 0.8]
  if state = "fighting" [set fatigue-level fatigue-level + 1.2]
  if state = "wandering" [set fatigue-level fatigue-level + 0.2]

  ; Update speed based on energy AND fatigue
  let fatigue-penalty (fatigue-level / 100) * 0.3  ; Fatigue can reduce speed by up to 30%
  set speed max (list 0.1 ((energy / 100) * 0.9 - fatigue-penalty))

  ; Death check (from hunger or no energy)
  if energy <= 0 or hunger-level >= 100 [
    set state "corpse"
    set color gray
    stop
  ]

  ; Handle infection progression
  if state = "infected" [
    handle-infection
    stop
  ]

  ; MODIFIED: Check if human needs to rest (hide for sleep)
  if (fatigue-level > 80 or energy < 20) and state != "hiding" and state != "running" [
    ; Look for safe place to rest
    if any? patches in-radius 3 with [pcolor = black or pcolor = gray or is-shelter] [
      move-to one-of patches in-radius 3 with [pcolor = black or pcolor = gray or is-shelter]
      set state "hiding"
      set hiding-reason "rest"
      set rest-timer 0
    ]
  ]

  ; OPTION A: Allow stress conflicts even during zombie encounters
  if stress-level > 90 and any? other humans in-radius 2 [
    ; Panic-induced conflicts even during zombie encounters
    if random 100 < 10 [  ; 10% chance when extremely stressed
      initiate-intragroup-conflict other humans in-radius 2
    ]
  ]

  ; RCT-specific behavior assessment
  assess-competitive-state

  ; State-based behavior
  (ifelse
    state = "wandering" [wander-behavior]
    state = "running" [run-behavior]
    state = "hiding" [hide-rest-behavior]  ; MODIFIED: New combined behavior
    state = "fighting" [fight-behavior]
  )

  ; Consume resources if hungry
  if hunger-level > 70 and resource-inventory > 0 [
    eat-food
  ]
end

; Add this procedure to your code
to eat-food
  if resource-inventory > 0 [
    ; Consume some resources to reduce hunger
    let food-consumed min (list 20 resource-inventory)
    set resource-inventory resource-inventory - food-consumed
    set hunger-level max (list (hunger-level - food-consumed) 0)

    ; Also restore some energy from eating
    set energy min (list (energy + food-consumed * 0.5) 100)
  ]
end

; Assess competitive state based on RCT principles
; REPLACE your assess-competitive-state procedure with this:
to assess-competitive-state
  let nearby-humans other humans in-radius vision-range
  let nearby-resources resources in-radius vision-range

  ; OPTION C: Allow resource hoarding during crisis - desperation overrides even zombie threats
  if hunger-level > 95 and any? nearby-resources [
    let visible-zombies zombies in-radius vision-range
    ; Even with zombies nearby, extreme desperation drives resource competition
    if any? visible-zombies and any? nearby-humans [
      set competitive-state "hostile"
      ; Force conflict over critical resources even during zombie encounters
      if random 100 < 30 [  ; 30% chance when desperately hungry and zombies present
        initiate-intragroup-conflict nearby-humans
      ]
    ]
  ]

  ; Check for resource competition within the group
  if any? nearby-resources and any? nearby-humans [
    let competing-humans nearby-humans

    ; FIXED: Competition happens when resources are SCARCE (high pressure)
    if any? competing-humans and current-resource-pressure > 40 [
      set competitive-state "competing"

      ; Mark resource as contested
      ask nearby-resources [set contested? true]

      ; FIXED: Lower threshold for conflict, higher chance when desperate
      if (resource-competition > 50 or hunger-level > 80) and random 100 < (current-resource-pressure / 2) [
        set competitive-state "hostile"
        initiate-intragroup-conflict competing-humans
      ]
    ]
  ]

  ; FIXED: Only cooperate when resources are abundant AND no hunger desperation
  if current-resource-pressure < 30 and cooperation-level > 60 and hunger-level < 60 [
    if any? nearby-humans and competitive-state != "hostile" [
      set competitive-state "cooperating"
    ]
  ]

  ; FIXED: Force competition when individual is desperate
  if hunger-level > 85 or resource-inventory < 5 [
    set competitive-state "competing"
    set resource-competition min (list (resource-competition + 5) 100)
  ]
end

; Initiate conflict within the group over resources
to initiate-intragroup-conflict [competitors]
  ; Increment the conflicts counter for this tick
  set conflicts-this-tick conflicts-this-tick + 1

  ; Debug output
  print (word "CONFLICT INITIATED! Current conflicts this tick: " conflicts-this-tick " | Total conflicts so far: " total-conflicts-cumulative)

  ask competitors [
    if distance myself <= 3 [  ; Increased range
      ; Engage in intragroup conflict
      set intergroup-conflicts intergroup-conflicts + 1
      set competitive-state "hostile"

      ; Visual feedback - make conflicts obvious
      set color red
      set size 2  ; Make hostile humans bigger/more visible

      ; Add to enemy list (within same group)
      if not member? [who] of myself enemy-list [
        set enemy-list lput [who] of myself enemy-list
      ]

      ; Stronger conflict effects
      set trust-level max (list (trust-level - 25) 0)
      set stress-level min (list (stress-level + 30) 100)
      set resource-competition min (list (resource-competition + 20) 100)

      ; Reduce group cohesion more dramatically
      set group-loyalty max (list (group-loyalty - 15) 0)

      ; Mark area as conflict zone
      ask patch-here [
        set conflict-zone? true
        set pcolor red  ; Visual indicator of conflict
      ]

      ; Add some resource stealing in conflicts
      if resource-inventory > 0 and [resource-inventory] of myself < resource-inventory [
        let stolen min (list 10 resource-inventory)
        set resource-inventory resource-inventory - stolen
        ask myself [set resource-inventory resource-inventory + stolen]
      ]
    ]
  ]
end

; Add missing procedure for corpse handling
to update-corpse-state
  ; Corpses just stay in place and decay
  set color gray
  set size size * 0.99  ; Slowly shrink

  ; Remove corpse after some time
  if size < 0.1 [
    die
  ]
end

to zombie-behavior
  rt random 50 - random 50
  fd speed * 0.5
end

; ----- STATE-SPECIFIC BEHAVIORS -----

; Enhanced wandering behavior with RCT considerations
to wander-behavior
  ; Set color based on competitive state - NEW VISUAL INDICATORS
  (ifelse
    competitive-state = "competing" [set color brown]     ; Brown: competing for resources
    competitive-state = "cooperating" [set color magenta] ; Magenta: cooperating
    competitive-state = "hostile" [set color blue]       ; Blue: hostile toward members
    [set color pink] ; neutral
  )

  ; First priority: Check for nearby zombies
  let visible-zombies zombies in-radius vision-range
  if any? visible-zombies [
    ifelse strength > 1 and count visible-zombies = 1 and skill-combat > 1 [
      set state "fighting"
    ][
      set state "running"
    ]
    stop
  ]

  ; Second priority: Resource gathering with intragroup RCT considerations
  if hunger-level > 50 or resource-inventory < 30 [
    let visible-resources resources in-radius vision-range
    if any? visible-resources [
      let target-resource min-one-of visible-resources [distance myself]

      ; Check for competition with other group members
      let competitors other humans in-radius vision-range

      if-else any? competitors and current-resource-pressure > 60 [
        ; Intragroup resource competition scenario
        handle-intragroup-resource-competition target-resource competitors
      ] [
        ; No competition, proceed normally
        face target-resource
        fd speed

        if distance target-resource < 1 [
          collect-resource target-resource
        ]
      ]
      stop
    ]
  ]

  ; Third priority: Intragroup interactions
  handle-intragroup-interactions

  ; Default: Wander randomly
  rt random 50 - random 50
  fd speed * 0.5
end

; Handle intragroup resource competition scenarios
to handle-intragroup-resource-competition [target-resource competitors]
  let closest-competitor min-one-of competitors [distance target-resource]

  (ifelse
    ; FIXED: Desperate hunger overrides everything
    hunger-level > 85 [
      ; Desperately hungry - very aggressive
      face target-resource
      fd speed * 2
      set stress-level min (list (stress-level + 15) 100)
      set competitive-state "hostile"

      ; Force conflict if someone else is close
      if any? competitors with [distance target-resource < 2] [
        initiate-intragroup-conflict competitors
      ]
    ]

    ; FIXED: High resource pressure = competition (not cooperation)
    current-resource-pressure > 60 and distance target-resource < [distance target-resource] of closest-competitor [
      ; Aggressively claim resource when resources are scarce
      face target-resource
      fd speed * 1.5
      set stress-level min (list (stress-level + 10) 100)
      set competitive-state "competing"

      ; Higher chance of conflict when resources very scarce
      if current-resource-pressure > 80 and random 100 < 40 [
        initiate-intragroup-conflict competitors
      ]
    ]

    ; FIXED: Only cooperate when resources are ABUNDANT
    current-resource-pressure < 30 and cooperation-level > 70 and hunger-level < 50 [
      ; Share only when resources aren't scarce and not hungry
      if random 100 < 50 [
        face target-resource
        fd speed * 0.8
        set cooperation-events cooperation-events + 1
        set competitive-state "cooperating"
      ]
    ]

    ; Default: Compete for resource
    [
      face target-resource
      fd speed * 1.2
      set competitive-state "competing"
    ]
  )
end

; Handle interactions within the group
; Fix the cooperation check in handle-intragroup-interactions
to handle-intragroup-interactions
  let nearby-humans other humans in-radius vision-range

  if any? nearby-humans [
    let closest-human min-one-of nearby-humans [distance myself]

    ; FIXED: Only cooperate when NOT desperate and resources abundant
    if cooperation-level > 50 and current-resource-pressure < 30 and hunger-level < 60 [
      ; Move closer to help group cohesion
      if distance closest-human > 3 [
        face closest-human
        fd speed * 0.3
      ]

      ; Share resources only when abundant and not hungry
      if resource-inventory > 70 and current-resource-pressure < 30 [
        ask closest-human [
          if resource-inventory < 30 [
            set resource-inventory resource-inventory + 10
            ask myself [set resource-inventory resource-inventory - 10]
            set cooperation-events cooperation-events + 1
            set competitive-state "cooperating"
          ]
        ]
      ]
    ]

    ; FIXED: Competition and conflict when resources scarce OR hungry
    if (current-resource-pressure > 50 or hunger-level > 70) and not superordinate-active? [
      ; Increase competition when desperate
      set resource-competition min (list (resource-competition + 2) 100)

      ; FIXED: Much higher chance of conflict when desperate
      let conflict-chance current-resource-pressure + (hunger-level / 2)
      if distance closest-human < 3 and random 100 < (conflict-chance / 3) [
        ; Intragroup conflict more likely when desperate
        face closest-human
        rt 180  ; Turn away aggressively
        fd speed * 0.7
        set stress-level min (list (stress-level + 15) 100)
        set trust-level max (list (trust-level - 10) 0)

        ; Trigger actual conflict
        initiate-intragroup-conflict (turtle-set closest-human)
        set intergroup-conflicts intergroup-conflicts + 1
        set competitive-state "hostile"
      ]
    ]
  ]
end

; NEW: Combined hiding and resting behavior
to hide-rest-behavior
  ; Color coding based on why they're hiding
  (ifelse
    hiding-reason = "safety" [set color orange]      ; Orange: hiding from danger
    hiding-reason = "rest" [set color cyan]          ; Cyan: resting/sleeping
    hiding-reason = "both" [set color violet]        ; Violet: both safety and rest
  )

  ; Increment rest timer
  set rest-timer rest-timer + 1

  ; RESTING BENEFITS (but limited without food)
  if hiding-reason = "rest" or hiding-reason = "both" [
    ; Reduce fatigue while resting (primary benefit)
    set fatigue-level max (list (fatigue-level - 2) 0)

    ; Small energy recovery from rest, but much less than from food
    set energy min (list (energy + 0.5) 100)

    ; Reduce stress while resting
    set stress-level max (list (stress-level - 2) 0)

    ; Better rest in shelters
    if [is-shelter] of patch-here [
      set fatigue-level max (list (fatigue-level - 3) 0)  ; Extra fatigue reduction
      set energy min (list (energy + 1) 100)              ; Slightly better energy recovery
      set stress-level max (list (stress-level - 3) 0)    ; Extra stress reduction
    ]
  ]

  ; SAFETY BENEFITS (traditional hiding)
  if hiding-reason = "safety" or hiding-reason = "both" [
    ; Reduce stress from hiding from danger
    set stress-level max (list (stress-level - 3) 0)
  ]

  ; OPTION C: Even while resting, allow resource hoarding conflicts if critically desperate
  if hunger-level > 95 and any? resources in-radius vision-range [
    let nearby-humans other humans in-radius vision-range
    if any? nearby-humans and random 100 < 15 [  ; 15% chance when desperately hungry
      set state "wandering"  ; Break from hiding to compete for resources
      set hiding-reason "none"
      set rest-timer 0
      initiate-intragroup-conflict nearby-humans
    ]
  ]

  ; Check if should stop hiding/resting
  let visible-zombies zombies in-radius vision-range
  let should-stop-hiding false

  ; Stop hiding from safety when no longer threatened
  if hiding-reason = "safety" and not any? visible-zombies [
    if random 100 < 70 [  ; 70% chance per tick to stop hiding from safety
      set should-stop-hiding true
    ]
  ]

  ; Stop resting when well-rested OR urgent needs
  if hiding-reason = "rest" [
    ; Stop if well-rested
    if fatigue-level < 20 and energy > 60 [
      set should-stop-hiding true
    ]
    ; Stop if urgent zombie threat
    if any? visible-zombies [
      set hiding-reason "safety"  ; Switch to hiding for safety
      set should-stop-hiding false
    ]
    ; Stop if desperately hungry and resources available
    if hunger-level > 90 and any? resources in-radius vision-range [
      set should-stop-hiding true
    ]
  ]

  ; Handle "both" case
  if hiding-reason = "both" [
    ; Only stop when both conditions are met: safe and rested
    if not any? visible-zombies and fatigue-level < 20 and energy > 60 [
      if random 100 < 50 [  ; 50% chance to stop when both conditions met
        set should-stop-hiding true
      ]
    ]
    ; Or if desperately hungry
    if hunger-level > 90 and any? resources in-radius vision-range [
      set should-stop-hiding true
    ]
  ]

  ; Actually stop hiding if conditions are met
  if should-stop-hiding [
    set state "wandering"
    set hiding-reason "none"
    set rest-timer 0
  ]

  ; Force wake up if hiding too long (avoid getting stuck)
  if rest-timer > 50 [  ; After 50 ticks of hiding
    set state "wandering"
    set hiding-reason "none"
    set rest-timer 0
  ]
end

; MODIFIED: Running state - fleeing from zombies with rest consideration
to run-behavior
  set color yellow

  ; Find zombies in visual range
  let visible-zombies zombies in-radius vision-range

  ifelse any? visible-zombies [
    ; OPTION C: Even while running from zombies, allow resource conflicts if desperate
    if hunger-level > 95 and any? resources in-radius vision-range [
      let nearby-humans other humans in-radius vision-range
      if any? nearby-humans and random 100 < 20 [  ; 20% chance when desperately hungry
        initiate-intragroup-conflict nearby-humans
      ]
    ]

    ; Run away from nearest zombie
    let nearest-zombie min-one-of visible-zombies [distance myself]
    if nearest-zombie != nobody [
      face nearest-zombie
      rt 180  ; Turn around
      fd speed * 1.3  ; Run faster than normal

      ; Running consumes more energy AND increases fatigue significantly
      set energy energy - 0.3
      set fatigue-level min (list (fatigue-level + 1.5) 100)  ; NEW: Running is very tiring
      set stress-level min (list (stress-level + 3) 100)

      ; Look for hiding spots
      if any? patches in-radius 2 with [pcolor = black or pcolor = gray or is-shelter] [
        move-to one-of patches in-radius 2 with [pcolor = black or pcolor = gray or is-shelter]
        set state "hiding"
        set hiding-reason "safety"  ; NEW: Hiding for safety, not rest
        set rest-timer 0
      ]
    ]
  ][
    ; No zombies visible anymore, return to wandering
    set state "wandering"
    set stress-level max (list (stress-level - 5) 0)  ; Reduce stress slightly
  ]
end

to fight-behavior
  set color white
  let visible-zombies zombies in-radius vision-range

  ; OPTION C: Even during zombie combat, allow resource conflicts if critically desperate
  if hunger-level > 95 and any? resources in-radius vision-range [
    let nearby-humans other humans in-radius vision-range
    if any? nearby-humans and random 100 < 25 [  ; 25% chance - higher during combat stress
      initiate-intragroup-conflict nearby-humans
    ]
  ]

  ; Should there be a zombie, lock on 1 only
  if any? visible-zombies [
    let target min-one-of visible-zombies [distance myself]
    face target

    ; Chase vs attack
    ifelse distance target > 1 [
      fd speed * 1.2
      set energy energy - 0.2
      set fatigue-level min (list (fatigue-level + 0.8) 100)  ; NEW: Fighting is tiring
    ] [
      ; now you're close enough—attack!
      let attack-power strength + (skill-combat / 20) + random 3
      ask target [
        set health health - attack-power
        if health <= 0 [
          die
          ask myself [
            set skill-combat min (list (skill-combat + 3) 100)
          ]
        ]
      ]
      set energy max (list (energy - 2) 0)
      set fatigue-level min (list (fatigue-level + 2) 100)  ; NEW: Combat is very tiring
      set stress-level min (list (stress-level + 3) 100)
    ]

    ; If low energy OR very fatigued, run or hide to rest
    if energy < 20 or fatigue-level > 85 or (count zombies in-radius vision-range) > 1 [
      ifelse fatigue-level > 85 [
        ; Too tired to keep running, need to hide and rest
        if any? patches in-radius 3 with [pcolor = black or pcolor = gray or is-shelter] [
          move-to one-of patches in-radius 3 with [pcolor = black or pcolor = gray or is-shelter]
          set state "hiding"
          set hiding-reason "both"  ; NEW: Hiding for both safety and rest
          set rest-timer 0
        ]
      ][
        set state "running"
      ]
    ]
  ] [
    ; ELSE: no zombies at all
    set state "wandering"
  ]
end

; ----- HELPER FUNCTIONS ----

; Handle infection progression
to handle-infection
  set color violet

  ; Infection timer counts down
  set infection-timer max (list( infection-timer - 1) 0)

  ; Infection drains energy and increases fatigue
  set energy max (list (energy - 2) 0)
  set fatigue-level min (list (fatigue-level + 1) 100)  ; NEW: Infection is exhausting

  ; Infected humans move erratically but slowly
  rt random 90 - random 90
  fd speed * 0.3

  ; When timer reaches 0, turn into zombie
  if infection-timer <= 0 [
    transform-to-zombie
  ]
end

to transform-to-zombie
  ; Create new zombie at location
  hatch-zombies 1 [
    set shape "person"
    set color red
    set size 1.5
    move-to one-of patches with [not any? turtles-here]

    ; Initialize zombie properties
    set health 75 + random 25          ; Initial health of zombie
    set speed 0.3 + random-float 0.3   ; Zombies are slower than humans
    set strength 8 + random 4          ; But stronger
    set state "wandering"
    set vision-range 3 + random 2      ; Poor vision
    set hearing-range 6 + random 4     ; Good hearing
    set satiation 0                    ; Start hungry
  ]

  ; Remove human
  die
end

; Collect resource when found
to collect-resource [res]
  set color blue
  ; Increase resource inventory
  set resource-inventory resource-inventory + [amount] of res
  set stress-level max (list (stress-level - 3) 0)

  ; Improve gathering skill
  set skill-gathering min (list (skill-gathering + 3) 100)

  ; Resource gathering increases fatigue slightly
  set fatigue-level min (list (fatigue-level + 0.5) 100)  ; NEW: Gathering is work

  ; Update resource
  ask res [die] ; Resource is consumed
end
@#$#@#$#@
GRAPHICS-WINDOW
257
13
694
451
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
32
106
242
139
initial-human-population
initial-human-population
2
10
8.0
1
1
NIL
HORIZONTAL

SLIDER
32
151
244
184
initial-zombie-population
initial-zombie-population
0
30
13.0
1
1
NIL
HORIZONTAL

SLIDER
35
202
225
235
initial-resource-count
initial-resource-count
0
100
19.0
1
1
NIL
HORIZONTAL

BUTTON
59
36
126
69
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
134
36
197
69
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
735
48
935
198
Average Hunger Level
Time (ticks)
Average Hunger Level
0.0
1000.0
0.0
100.0
true
false
"" ""
PENS
"hunger" 1.0 0 -16777216 true "" ""

MONITOR
731
212
790
257
Humans
count humans
17
1
11

MONITOR
796
212
856
257
zombies
count zombies
17
1
11

PLOT
947
48
1147
198
Total Conflicts Over Time
Ticks
Conflicts
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"total-conflicts" 1.0 0 -2674135 true "" ""

TEXTBOX
730
275
931
443
Pink: Neutral state\nBrown: Competing for resources\nMagenta: Cooperating with others\nBlue: Hostile toward group members\nRed: In active conflict (larger size too)\nYellow: Running from zombies\nWhite: Fighting zombies
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
