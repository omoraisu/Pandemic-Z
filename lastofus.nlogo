; PANDEMIC Z - Dynamic Role Adaptation

; ----- BREEDS -----
breed [humans human]
breed [zombies zombie]
breed [resources resource]

; ----- GLOBALS -----
globals [
  day
  resource-scarcity
  total-conflicts
]

; ----- AGENT PROPERTIES -----
humans-own [
  ; Physical
  energy
  speed
  strength
  state
  vision-range

  ; Resources
  resource-inventory

  ; Psychological
  stress-level
  trust-level
  cooperation-level

  ; Skills (now dynamic)
  skill-combat
  skill-gathering

  ; Role (now adaptive - only fighter or gatherer)
  role
  last-action
  combat-actions
  gathering-actions

  ; NEW: Performance tracking for dynamic adaptation
  combat-success-count
  combat-attempt-count
  gather-success-count
  gather-attempt-count
  defense-success-count
  defense-attempt-count

  ; NEW: Experience-based learning
  combat-experience
  gathering-experience

  ; NEW: Role confidence and adaptation
  role-confidence
  role-change-cooldown
  last-role-change-tick

  ; NEW: Performance history for better decision making
  recent-combat-success    ; rolling average of recent combat success
  recent-gather-success    ; rolling average of recent gathering success

  ; Zombiefication
  infection-timer
]

zombies-own [
  health             ; 0-100
  speed              ; typically slower than humans
  strength           ; determines damage to humans
  state              ; "wandering", "chasing", "feeding", "following-horde", "breaking-in"
  vision-range       ; typically poor
  hearing-range      ; typically good
  satiation          ; increases when feeding, decreases over time

  target-human       ; which human this zombie is chasing
  horde-leader?      ; is this zombie leading a horde chase
  following-zombie   ; which zombie this one is following in horde
  chase-timer        ; how long they've been chasing current target

  age-ticks          ; how long this zombie has existed
  decay-rate         ; individual decay speed (varies by zombie)
  max-lifespan       ; when this zombie will die from decay (3-5 years in ticks)

  ; SHELTER BREAKING PROPERTIES
  target-shelter     ; which shelter this zombie is trying to break into
  break-progress     ; progress on breaking into current shelter
]

resources-own [
  amount
]

patches-own [
  resource-level     ; amount of available resources (0-100)
  is-shelter         ; boolean if patch is shelter
  zombie-scent       ; for zombie tracking of humans

  ; NEW SHELTER PROPERTIES
  shelter-integrity  ; 0-100, how intact the shelter is
  being-broken?      ; boolean, is zombie currently breaking in
  break-timer        ; ticks needed to break in completely
  max-break-time     ; total time needed to break in (varies by shelter quality)
]

; ----- SETUP PROCEDURES -----
to setup
  clear-all
  setup-environment
  setup-humans
  setup-zombies
  setup-resources
  set total-conflicts 0
end

; Create the environment with varied terrain
to setup-environment

  ; Initialize all patches with base properties first
  ask patches [
    set resource-level 0
    set is-shelter false
    set zombie-scent 0

    ; Initialize shelter properties for all patches
    set shelter-integrity 20
    set being-broken? false
    set break-timer 0
    set max-break-time 0
  ]

  ; Load the urban map from file
  file-open "map.txt"
  let y max-pycor

  while [not file-at-end?] [
    let row file-read-line
    let x min-pxcor
    let i 0

    ; Process each character in the row without explode function
    while [i < length row] [
      let char substring row i (i + 1)
      ask patch x y [
        if char = "W" [       ; Blank spaces
          set pcolor black
        ]
        if char = "G" [       ; Resource areas
          set resource-level 15 + random-float 25   ; High resources (15-40)
          set pcolor scale-color lime resource-level 0 50
        ]
        if char = "O" [       ; Shelters
          ; Initialize shelters with full properties
          set is-shelter true
          set pcolor orange

          set max-break-time (shelter-integrity / 2) + random 30
          set being-broken? false
          set break-timer 0
        ]
      ]
      set x x + 1
      set i i + 1
    ]
    set y y - 1
  ]

  file-close

  ; Initialize resources in resource areas
  setup-resources

  ; Set initial game values
  set day 1
  set resource-scarcity 50  ; Medium scarcity to start

  reset-ticks
end

to setup-humans
  create-humans initial-human-population [
    set shape "person"
    set color white
    set size 2
    move-to one-of patches with [pcolor = orange and not any? humans-here]

    ; Initialize properties
    ; Physical
    set energy 75 + random 25
    set speed 0.5 + random-float 0.5
    set strength  7 + random 3
    set state "wandering"
    set vision-range 3 + random 2

    ; Resources
    set resource-inventory  20 + random 30

    ; Psychological
    set stress-level 30 + random 70
    set trust-level 30 + random 70
    set cooperation-level 30 + random 70

    ; Skills - START WITH NEUTRAL VALUES
    set skill-combat 20 + random 10    ; 15-25 range
    set skill-gathering 15 + random 10 ; 15-25 range

    ; Role - START AS GENERALIST (will quickly adapt to fighter or gatherer)
    set role "generalist"
    set color white  ; neutral color
    set last-action "none"
    set combat-actions 0
    set gathering-actions 0

    ; NEW: Initialize performance tracking
    set combat-success-count 0
    set combat-attempt-count 0
    set gather-success-count 0
    set gather-attempt-count 0
    set defense-success-count 0
    set defense-attempt-count 0

    ; NEW: Initialize experience
    set combat-experience 5
    set gathering-experience 5

    ; NEW: Initialize role adaptation
    set role-confidence 50  ; neutral confidence
    set role-change-cooldown 20  ; ticks before can change role again
    set last-role-change-tick 0

    ; NEW: Initialize performance averages
    set recent-combat-success 0.5   ; neutral starting point
    set recent-gather-success 0.5   ; neutral starting point

    ; Not infected at start
    set infection-timer 0
  ]
end

to setup-zombies
  create-zombies initial-zombie-population [
    set shape "person"
    set color red
    set size 2
    move-to one-of patches with [not any? turtles-here]

    set health 30 + random 20
    set speed 0.2
    set strength 3 + random 7
    set state "wandering"
    set vision-range 2 + random 2
    set hearing-range 3 + random 2
    set satiation 0

    set target-human nobody
    set horde-leader? false
    set following-zombie nobody
    set chase-timer 0

    set age-ticks 0
    set decay-rate 0.01 + random-float 0.04
    set max-lifespan 700 + random 300
  ]
end

; Setup resources only in designated resource areas (green patches)
to setup-resources
  ask patches with [pcolor >= green and pcolor <= lime] [
    ; Each resource patch has a chance to contain a resource based on resource-level
    let spawn-chance (resource-level / 40) * 70  ; Higher resource-level = higher spawn chance
    if random-float 100 < spawn-chance [
      sprout 1 [
        set breed resources
        set color yellow
        set shape "circle"
        set size 0.8
        set amount 10 + random 20
      ]
    ]
  ]
end

to respawn-resources
  ask patches with [pcolor >= green and pcolor <= lime and not any? resources-here] [
    ; Chance to respawn based on resource-level and resource-scarcity
    let respawn-chance (resource-level / 50) * (100 - resource-scarcity) / 100 * 15
    if random-float 100 < respawn-chance [
      sprout 1 [
        set breed resources
        set color yellow
        set shape "circle"
        set size 0.8
        set amount 10 + random 20
      ]
    ]
  ]
end

; ----- MAIN PROCEDURES -----
to go
  ; Stop simulation if no more humans
  if not any? humans [stop]

  if ticks mod 50 = 0 [
    set day day + 1
  ]

  ask humans [
    human-behavior
    ; NEW: Update role adaptation every few ticks
    if ticks mod 10 = 0 [
      update-role-adaptation
    ]
  ]

  ask zombies [zombie-behavior]

  respawn-resources
  tick
end

to human-behavior
  ; 1. Metabolism & health checks first
  update-energy-level
  death-check

  ; 2. Update stress early, since stress affects behavior
  update-stress

  ; 3. If stress is very high, prioritize hiding and recovering stress
  if stress-level > 80 [
    hide-and-recover
    stop  ;; do nothing else this tick
  ]

  ; 3.5 If energy is enough, help comrades
  if energy > 30 [  ; Only help if you have enough energy
    help-others-in-combat
  ]


  ; 4. If energy is sufficient, do main tasks
  if energy > 20 [
    perform-task
    cooperate-with-others
  ]

  ; 5. If resources are low, ask for resources (might involve cooperation)
  if resource-inventory < 30 [
    ask-for-resources
  ]

  ; 6. Consume resources last, after tasks and cooperation
  consume-resources

  ; 7. Update trust and cooperation levels based on last actions
  update-trust-cooperation

  ; 8. Check if there is conflict between the group based on trust level and stress level
  check-for-conflict

  ; 9. Movement or wandering as fallback or end-of-turn activity
  if last-action = "none" [
    wander
  ]
end

; NEW: Dynamic role adaptation based on performance - simplified to two roles
to update-role-adaptation
  ; Only adapt if cooldown period has passed
  if (ticks - last-role-change-tick) < role-change-cooldown [
    stop
  ]

  ; Calculate performance metrics
  let combat-success-rate 0.2
  let gather-success-rate 0.2

  if combat-attempt-count > 3 [
    set combat-success-rate (combat-success-count / combat-attempt-count)
  ]

  if gather-attempt-count > 3 [
    set gather-success-rate (gather-success-count / gather-attempt-count)
  ]

  ; Update rolling averages (weighted toward recent performance)
  set recent-combat-success (recent-combat-success * 0.7 + combat-success-rate * 0.3)
  set recent-gather-success (recent-gather-success * 0.7 + gather-success-rate * 0.3)

  ; Determine best role based on performance - only fighter vs gatherer
  let best-combat-score recent-combat-success + (combat-experience / 100)
  let best-gather-score recent-gather-success + (gathering-experience / 100)

  ; Role change logic with confidence thresholds
  let old-role role
  let role-change-threshold 0.15  ; need significant difference to change

  ; Determine new role - simplified to two roles
  let new-role role
  if best-combat-score > best-gather-score + role-change-threshold [
    set new-role "fighter"
  ]

  if best-gather-score > best-combat-score + role-change-threshold [
    set new-role "gatherer"
  ]

  ; If no clear winner and currently generalist, pick randomly weighted by slight preference
  if role = "generalist" [
    ifelse best-combat-score > best-gather-score [
      set new-role "fighter"
    ] [
      set new-role "gatherer"
    ]
  ]

  ; Apply role change if different
  if new-role != old-role [
    set role new-role
    set last-role-change-tick ticks
    update-role-appearance

    ; Boost confidence when finding a good role
    set role-confidence min(list 100 (role-confidence + 20))

    ; Adjust skills based on specialization
    specialize-skills
  ]
end

; NEW: Update appearance based on role - simplified to two roles
to update-role-appearance
  if role = "fighter" [ set color blue ]
  if role = "gatherer" [ set color pink ]
  if role = "generalist" [ set color white ]
end

; NEW: Adjust skills when specializing - simplified to two roles
to specialize-skills
  if role = "fighter" [
    set skill-combat min(list 100 (skill-combat + 5))
  ]

  if role = "gatherer" [
    set skill-gathering min(list 100 (skill-gathering + 5))
  ]
end

to update-energy-level
  ;; Default passive drain
  let drain 0.1

  ;; Adjust based on last action
  if last-action = "wander"         [ set drain 0.1 ]
  if last-action = "run"            [ set drain 1.0 ]
  if last-action = "hide"           [ set drain 0.1 ]
  if last-action = "defend"         [ set drain 1.2 ]
  if last-action = "attack"         [ set drain 1.2 ]
  if last-action = "conflict"       [ set drain 1.0 ]

  ;; Apply the drain, but never go below 1
  set energy max (list 1 (energy - drain))
end

to update-trust-cooperation
  ; Base constant increase each tick (small)
  set trust-level min (list 100 (trust-level + 0.05))
  set cooperation-level min (list 100 (cooperation-level + 0.05))

  ; Positive actions
  if last-action = "share" [
    set trust-level min (list 100 (trust-level + 5))
    set cooperation-level min (list 100 (cooperation-level + 5))
  ]

  if last-action = "receive" [
    set trust-level min (list 100 (trust-level + 3))
    set cooperation-level min (list 100 (cooperation-level + 3))
  ]

  if last-action = "defend" [
    set trust-level min (list 100 (trust-level + 4))
    set cooperation-level min (list 100 (cooperation-level + 4))
  ]

  if last-action = "join-ally" [
    set trust-level min (list 100 (trust-level + 5))
    set cooperation-level min (list 100 (cooperation-level + 5))
  ]

  if last-action = "dismissive" [
    set trust-level max (list 0 (trust-level - 6))
    set cooperation-level max (list 0 (cooperation-level - 6))
  ]

  ;; Reset to prevent repeated adjustments
  set last-action "none"
end

to update-stress
  set stress-level min (list 100 (stress-level + 0.1))

  let zombies-nearby count zombies in-radius vision-range
  let on-shelter? (pcolor = orange or is-shelter)

  if zombies-nearby > 0 [
    ;; Increase stress if zombies nearby
    set stress-level min (list 100 (stress-level + 2 * zombies-nearby))
  ]
  if on-shelter? [
    ;; Decrease stress gradually if on shelter
    set stress-level max (list 0 (stress-level - 5))
  ]
  if last-action = "conflict" [
    set stress-level min (list 100 (stress-level + 5))
  ]
end

to death-check
  if energy <= 0 [
    set state "corpse"
    set color gray
    die
  ]
end

to perform-task
  ; Task selection now based on current role and situation
  let zombies-nearby zombies in-radius vision-range
  let resources-nearby resources in-radius vision-range

  ; Emergency: always fight if zombies very close regardless of role
  if any? zombies-nearby with [distance myself <= 2] [
    attack-zombie
    stop
  ]

  ; Role-based task selection - simplified to two roles
  if role = "fighter" [
    if any? zombies-nearby [
      attack-zombie
    ]
  ]

  if role = "gatherer" [
    if any? resources-nearby [
      gather-resources
    ]
  ]

  if role = "generalist" [
    ; Try to do what's most needed
    ifelse any? zombies-nearby [
      attack-zombie
    ] [
      if any? resources-nearby [
        gather-resources
      ]
    ]
  ]
end

; MODIFIED: Track performance in combat
to attack-zombie
  let visible-zombies zombies in-radius vision-range

  if any? visible-zombies [
    let target-zombie min-one-of visible-zombies [distance myself]
    face target-zombie

    ifelse distance target-zombie > 1 [
      fd speed * 1.2  ; Move closer if not yet in range
    ] [
      ; Attack and track performance
      set combat-attempt-count combat-attempt-count + 1

      ifelse random-float 40 < skill-combat [
        perform-attack target-zombie
        set combat-success-count combat-success-count + 1
        set combat-experience min(list 100 (combat-experience + 3))
        set last-action "attack"
      ] [
        ; Failed attack
        set last-action "missed-attack"
      ]
    ]
  ]
end

; MODIFIED: Track performance in gathering
to gather-resources
  let nearby-resources resources in-radius vision-range
  if any? nearby-resources [
    ; Check safety condition
    let zombies-nearby zombies in-radius vision-range
    let fighters-nearby humans with [role = "fighter"] in-radius vision-range

    ; Only gather if safe or have protection from fighters
    ifelse not any? zombies-nearby or any? fighters-nearby [
      let target-resource one-of nearby-resources
      face target-resource

      ; Move forward toward resource but only if not already close
      ifelse distance target-resource > 1 [
        fd speed
      ] [
        ; Close enough to gather - track performance
        set gather-attempt-count gather-attempt-count + 1

        let resource-amount [amount] of target-resource
        let space-left 100 - resource-inventory

        if space-left > 0 [
          let gathered-amount min (list resource-amount space-left)
          set resource-inventory resource-inventory + gathered-amount

          ask target-resource [ die ]
          set gather-success-count gather-success-count + 1
          set gathering-experience min(list 100 (gathering-experience + 2))
          set last-action "gather"
        ]
      ]
    ][
      ; Too dangerous - run away
      run-away
    ]
  ]
end

; Consume resources when energy is low
to consume-resources
  if energy < 30 and resource-inventory >= 10 [
    set resource-inventory resource-inventory - 10
    set energy energy + 10  ; assume 10 units restore 20 energy
    if energy > 100 [ set energy 100 ] ; cap energy at 100
    set last-action "consume"
  ]
end

; Ask for resources if trust level is high
to ask-for-resources
  if trust-level > 71 [
    let potential-donors other humans in-radius 2 with [resource-inventory > 30]

    if any? potential-donors [
      let donor one-of potential-donors
      ask donor [
        give-resources-to myself
      ]
      set last-action "ask"
      stop
    ]
  ]
end

to give-resources-to [recipient]
  if trust-level > 71 and cooperation-level > 71 [
    let spare resource-inventory - 30
    if spare > 0 [
      let needed 100 - [resource-inventory] of recipient
      let max-give min (list spare needed)
      let to-give random (max-give + 1)

      if to-give > 0 [
        set resource-inventory resource-inventory - to-give
        ask recipient [
          set resource-inventory resource-inventory + to-give
          set last-action "receive"
        ]
        set last-action "share"
        stop
      ]
    ]
  ]
end

to cooperate-with-others
  if trust-level > 71 and cooperation-level > 71 [

    ;; ===== RESOURCE SHARING =====
    let nearby-humans other humans in-radius 2 with [resource-inventory < 30]
    if any? nearby-humans [
      let needy one-of nearby-humans

      ;; Random chance to help vs ignore
      ifelse random-float 100 < 85 [ ; 85% chance to help
        give-resources-to needy
        stop
      ] [
        set last-action "dismissive"
        ;; optionally print or log it
        stop
      ]
    ]

    ;; ===== DEFEND OTHERS (only fighters do this) =====
    if role = "fighter" [
      let zombies-nearby zombies in-radius vision-range
      let humans-nearby other humans in-radius vision-range
      let endangered one-of humans-nearby with [
        any? zombies in-radius 1
      ]

      if endangered != nobody and any? zombies-nearby [
        ;; Random chance to defend
        if random-float 100 < 85 [ ; 90% chance to defend
                                   ;; Find a zombie near the endangered human
          let target-zombie min-one-of zombies-nearby [distance endangered]

          ;; Check if any other human fighter is near the zombie
          let allies-near-zombie humans with [
            role = "fighter" and self != myself and distance target-zombie <= 1.5
          ]

          ;; Move closer to ally first if there is one
          if any? allies-near-zombie [
            let chosen-ally one-of allies-near-zombie
            face chosen-ally
            if distance chosen-ally > 1 [
              fd speed * 1.2
              set last-action "join-ally"
              stop
            ]
          ]

          ;; Now proceed to attack the zombie
          face target-zombie
          if distance target-zombie > 1 [
            fd speed * 1.3
          ]

          ifelse random-float 100 < 90 [
            perform-attack target-zombie
            set defense-success-count defense-success-count + 1
            set defense-attempt-count defense-attempt-count + 1
            set last-action "defend"
            stop
          ] [
            set defense-attempt-count defense-attempt-count + 1
            set last-action "dismissive"
            stop
          ]
        ]
      ]
    ]
  ]
end

; MOVEMENT
to wander
  ; Simple random walk
  rt random 50 - random 50
  fd speed * 0.5
  set last-action "wander"
end

to run-away
  let nearest-zombie min-one-of zombies [distance myself]

  if nearest-zombie != nobody [
    face nearest-zombie
    rt 180                ; Turn and run opposite direction
    fd speed * 1.4        ; Move faster than usual
    set last-action "run"
    stop
  ]
end

to hide-and-recover
  let shelter-radius 2
  let current-patch patch-here

  ;; Check if already at a shelter patch
  ifelse pcolor = orange or is-shelter [
    ;; Reduce stress gradually while staying sheltered
    set stress-level max (list 0 (stress-level - 5))

    ;; If stress is low enough, wander again
    ifelse stress-level <= 20 [
      set last-action "recovered"
      wander
      stop
    ] [
      set last-action "recovering"
      ;; Stay put, do nothing else this tick
      stop
    ]
  ]
  ;; Otherwise try to move to a shelter nearby
   [
    let shelters patches in-radius shelter-radius with [pcolor = orange or is-shelter]
    ifelse any? shelters [
      move-to one-of shelters
      set last-action "hide"
      stop
    ] [
      ;; No shelter found, wander or run away (depends on context)
      wander
      stop
    ]
  ]
end

to perform-attack [target]
  ask target [
      set health health - ([strength] of myself * ([skill-combat] of myself / 100))
      if health <= 0 [ die ]
    ]
end

to help-others-in-combat
  ; Look for humans being attacked by zombies within vision range
  let humans-in-danger other humans in-radius vision-range with [
    any? zombies in-radius vision-range  ; humans with zombies very close (being attacked)
  ]

  if any? humans-in-danger [
    let human-to-help one-of humans-in-danger

    ; Find the zombie attacking that human
    let attacking-zombie min-one-of (zombies in-radius vision-range) [
      distance human-to-help
    ]

    if attacking-zombie != nobody [
      ; Move toward the zombie to help
      face attacking-zombie

      ifelse distance attacking-zombie > 1 [
        fd speed * 1.2  ; Move faster when helping
        set last-action "helping"
      ] [
        ; Close enough to attack - help fight the zombie
        set combat-attempt-count combat-attempt-count + 1

        ifelse random-float 40 < skill-combat [
          perform-attack attacking-zombie
          set combat-success-count combat-success-count + 1
          set combat-experience min(list 100 (combat-experience + 2))
          set last-action "helped-fight"
        ] [
          set last-action "missed-help"
        ]
      ]
      stop  ; Don't do other actions this tick
    ]
  ]
end

; --- FOR CONFLICT based on their trust level and stress level -----
to check-for-conflict
  let nearby-humans other humans in-radius vision-range
  if any? nearby-humans [
    let partner one-of nearby-humans
    if (stress-level > 70) and (trust-level < 40) [
      if random-float 100 < 20 [  ; 20% chance of conflict
        ; Apply effects of conflict
        set last-action "conflict"
        ; Affect the other human too
        ask partner [
          set last-action "conflict"
        ]
        set total-conflicts total-conflicts + 1
      ]
    ]
  ]
end

; --------ZOMBIE BEHAVIOR---------
to zombie-behavior
  handle-zombie-decay
  ; Skip behavior if dead from decay
  if health <= 0 [ die stop ]
  ; Update chase timer
  if chase-timer > 0 [
    set chase-timer chase-timer - 1
  ]
  ; State-based behavior
  (ifelse
    state = "wandering" [zombie-wander]
    state = "chasing" [zombie-chase]
    state = "following-horde" [zombie-follow-horde]
    state = "feeding" [zombie-feed]
    state = "breaking-in" [zombie-break-shelter]
  )
  ; Check for horde opportunities while wandering or chasing
  if state = "wandering" or state = "chasing" [
    check-for-horde-behavior
  ]
end
to handle-zombie-decay
  set age-ticks age-ticks + 1
  ; Begin decay after 3 years (~365 * 24 * 3 ticks)
  if age-ticks > 26280 [
    let decay-damage decay-rate * (age-ticks / 1000)
    set health health - decay-damage
    ; Visual decay indication
    set color scale-color red health 0 100
    ; Reduce abilities when weak
    if health < 30 [
      set speed speed * 0.8
      set strength strength * 0.9
      set vision-range max (list (vision-range - 0.1) 1)
    ]
  ]
  ; Mark for death from old age
  if age-ticks >= max-lifespan [
    set health 0
  ]
end
to zombie-wander
  let nearby-humans humans in-radius vision-range
  let heard-humans humans in-radius hearing-range
  ; Start chasing if human detected
  if any? nearby-humans or any? heard-humans [
    let all-detected-humans (turtle-set nearby-humans heard-humans)
    set target-human min-one-of all-detected-humans [distance myself]
    set state "chasing"
    set chase-timer 60  ; Give up after 100 ticks if can't catch
    set horde-leader? true  ; First to spot becomes leader
    stop
  ]
    ; Random wandering
      rt random 60 - random 30
      fd speed * 0.5
  ; Reduce satiation over time
  set satiation max (list (satiation - 0.1) 0)
end
to zombie-chase
  if target-human = nobody or [state] of target-human = "corpse" [
    reset-chase
    stop
  ]
  ; Give up if too far or timed out
  if chase-timer <= 0 or distance target-human > (vision-range * 3) [
    reset-chase
    stop
  ]
  ; Handle shelter detection
  if [state] of target-human = "hiding" and [[is-shelter] of patch-here] of target-human [
    let shelter-patch [patch-here] of target-human
    if [shelter-integrity] of shelter-patch > 0 [
      set state "breaking-in"
      set target-shelter shelter-patch
      set break-progress 0
      stop
    ]
  ]
  face target-human
  fd speed
  ; Check for attack opportunity, check if human is attackable in distance
  if distance target-human < 1 [
    let in-shelter? false
    if [state] of target-human = "hiding" and [[is-shelter] of patch-here] of target-human [
      set in-shelter? ([shelter-integrity] of patch-here) > 0
    ]
    if not in-shelter? [
      attack-human target-human
    ]
  ]
  ; Leave scent trail for horde
  ask patch-here [ set zombie-scent zombie-scent + 5 ]
end
to zombie-follow-horde
  if following-zombie = nobody or [state] of following-zombie != "chasing" [
    set state "wandering"
    set following-zombie nobody
    set target-human nobody
    ; reset-chase
    stop
  ]
  ; Follow the leader zombie
  face following-zombie
  fd speed * 0.9  ; Slightly slower than leader
  ; If close enough to leader's target, switch to chasing same target
  if [target-human] of following-zombie != nobody [
    set target-human [target-human] of following-zombie
    if distance target-human < vision-range [
      set state "chasing"
      set following-zombie nobody
      set chase-timer 60  ; Shorter timer for followers
    ]
  ]
end
to check-for-horde-behavior
  ; Only join horde if not already leading one
  if not horde-leader? and state != "following-horde" [
    ; Look for other zombies chasing humans
    let chasing-zombies other zombies in-radius (hearing-range * 1.5) with [
      state = "chasing" and target-human != nobody
    ]
    if any? chasing-zombies [
      ; Join the nearest chasing zombie's horde
      let leader min-one-of chasing-zombies [distance myself]
      ; Only join if the target is reasonably close
      if distance [target-human] of leader < (hearing-range * 2) [
        set following-zombie leader
        set target-human [target-human] of leader
        set state "following-horde"
        set chase-timer 60  ; Shorter commitment for followers
        set color scale-color red 50 0 100  ; Darker red for horde followers
      ]
    ]
  ]
end
to attack-human [target]
  if target != nobody [
    ask target [
      ; Apply damage and stress
      set energy energy - [strength] of myself
      ; Infect if not already infected (20% chance)
      if state != "infected" and random 100 < 15 [
        set state "infected"
        set infection-timer 50 + random 50
        set color violet
        stop
      ]
      ; Handle death
      if energy <= 0 [
        ifelse state = "infected" [
          transform-to-zombie
        ] [
          set state "corpse"
          set color gray
;          set total-deaths total-deaths + 1
;          set total-survivors total-survivors - 1
        ]
      ]
    ]
    ; Update zombie state after attack
    set state "feeding"
  ]
end

to zombie-break-shelter
  ; Abort if no valid shelter
  if target-shelter = nobody or not [is-shelter] of target-shelter [
    reset-breaking
    stop
  ]
  ; Move closer if not at shelter
  if patch-here != target-shelter [
    face target-shelter
    fd speed * 0.5
    stop
  ]
  ; Mark shelter as under attack
  ask target-shelter [
    set being-broken? true
    set break-timer break-timer + 1
    set pcolor scale-color red break-timer 0 max-break-time
  ]
  ; Track zombie’s own breaking progress
  set break-progress break-progress + 1
  let max-time [max-break-time] of target-shelter
  ; If shelter broken
  if break-progress >= max-time [
    ask target-shelter [
      set shelter-integrity 0
      set being-broken? false
      set pcolor gray
    ]
    ; Attack anyone inside
    let humans-inside humans-on target-shelter
    if any? humans-inside [
      set target-human one-of humans-inside
      attack-human target-human
    ]
    reset-breaking
    stop
  ]
  ; Give up if taking too long
  if break-progress > (max-time + 50) [
    ask target-shelter [
      set being-broken? false
      set break-timer 0
      set pcolor brown
    ]
    reset-breaking
  ]
end
to transform-to-zombie
  let current-patch patch-here
  ; Create new zombie at same location
  hatch-zombies 1 [
    set shape "person"
    set color red
    set size 2
    move-to current-patch

    set health 30 + random 20
    set speed 0.2 + random-float 0.3
    set strength 3 + random 7
    set state "wandering"
    set vision-range 2 + random 2
    set hearing-range 3 + random 2
    set satiation 0

    set target-human nobody
    set horde-leader? false
    set following-zombie nobody
    set chase-timer 0

    set age-ticks 0
    set decay-rate 0.01 + random-float 0.04
    set max-lifespan 500 + random 500

    set target-shelter nobody
    set break-progress 0
  ]
  ; Update global counters
  ; set total-infections total-infections + 1
  ; set total-survivors total-survivors - 1
  ; Remove original human
  die
end
; ------- HELPER FUNCTIONS ------------
to zombie-feed
  set satiation min (list (satiation + 5) 100)
  reset-chase
end
to reset-chase
  set state "wandering"
  set target-human nobody
  set horde-leader? false
  set chase-timer 0
end
to reset-breaking
  set state "wandering"
  set target-shelter nobody
  set break-progress 0
end

; ------ TO REPORT FUNCTIONS -------
to-report conflict
  report total-conflicts
end

to-report survival-rate
  if initial-human-population = 0 [ report 0 ]
  report (count humans / initial-human-population) * 100
end

to-report resource-efficiency
  let human-count count humans
  if human-count = 0 [ report 0 ]

  ;; Total available resources on map
  let total-available-resources sum [amount] of resources

  ;; Average cooperation in the population
  let avg-cooperation mean [cooperation-level] of humans

  ;; Normalize cooperation to 0–1
  let normalized-cooperation avg-cooperation / 100

  ;; Efficiency = resources adjusted by cooperation per person
  let efficiency (total-available-resources * normalized-cooperation) / human-count
  report efficiency
end

@#$#@#$#@
GRAPHICS-WINDOW
253
10
924
552
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
-25
25
-20
20
0
0
1
ticks
30.0

BUTTON
53
95
120
128
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

SLIDER
18
153
228
186
initial-human-population
initial-human-population
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
17
198
229
231
initial-zombie-population
initial-zombie-population
0
100
19.0
1
1
NIL
HORIZONTAL

BUTTON
131
95
195
129
NIL
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
20
260
220
410
Population Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"zombies" 1.0 0 -2674135 true "" "plot count zombies"
"humans" 1.0 0 -13345367 true "" "plot count humans"

TEXTBOX
26
433
176
461
Red Line - Zombies\nBlue Line - Humans
11
0.0
1

PLOT
967
18
1167
168
Survival Rate
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot survival-rate\n"

PLOT
974
383
1174
533
Conflict Frequency
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot conflict"

PLOT
968
202
1168
352
Resource Efficiency
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot resource-efficiency"

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
