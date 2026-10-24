/* Shared, read-only guidance. Opening help never submits or advances a journey. */
(() => {
  const guidance = {
    splash: ['Welcome to the Tao of Leela', 'Explore your experience through Leela, the I Ching, and your own reflection.', 'Choose Sign Up to begin, or Log In to return to your saved journey.'],
    login: ['Return to your journey', 'Sign in to access your Personas and their saved journeys.', 'Enter your registered user ID and password, then choose Log In.'],
    signup: ['Begin your journey', 'Create an account to keep your Personas, questions, castings, and reflections together.', 'Choose a user ID and a password of at least 10 characters, then select Sign Up.'],
    personas: ['Choose a Persona', 'Each Persona offers a distinct perspective with its own journey.', 'Choose Continue Journey on a Persona, Edit its details, or Create New Persona to explore another perspective.'],
    'create-persona': ['Create a Persona', 'Define the perspective from which you will experience the journey.', 'Give your Persona a name and add useful details. You may generate and accept an optional avatar. Choose Create Persona to begin.'],
    'edit-persona': ['Edit your Persona', 'Refine the perspective and details of an existing Persona.', 'Update the fields you wish to change, optionally generate and accept an avatar, then choose Save changes.'],
    progress: ['Your current experience', 'See your Persona’s current experience tile, where you came from, and possible movements.', 'Select a tile to explore its meaning. Choose Bring a question or Refine your question to prepare for casting.'],
    question: ['A focus for the casting', 'Add a question pertinent to the current experience tile, from the perspective of your Persona, to serve as the meditation focus during the yarrow stalk casting.', 'Write or refine your question, then choose Begin Casting. Where available, you can use a question from the last interpretation as a starting point.'],
    casting: ['The yarrow stalk casting', 'Hold your question in mind as the stalk ceremony forms six hexagram lines, from bottom to top.', 'Choose Next to advance each step. When all six lines are ready, choose See the Hexagram. Pause / Exit keeps your accepted progress for later.'],
    interpretation: ['Consider the interpretation', 'Explore the hexagram, changing lines, and interpretation in relation to your question and current experience.', 'Wait for the reading to appear, then choose Continue to your reflection. Select a hexagram for its reference details. If the reading fails, choose Retry interpretation.'],
    reflection: ['Your own reflection', 'Bring your own understanding, feelings, or further questions to the casting and its interpretation.', 'Write in Your journal, then choose Save / Continue to see the movement from this casting.'],
    movement: ['Movement and consequence', 'Review how the changing lines move your Persona, including any ladder, snake, or invitation to remain in place.', 'Choose Continue the Journey to acknowledge this movement and update your current experience tile.'],
    history: ['Your journey journal', 'Revisit saved questions, castings, interpretations, and personal reflections.', 'Expand an entry to read it. Choose Return to the journey when you are ready to continue.'],
    completion: ['Journey complete', 'Review your place of arrival and the encounters recorded along the way.', 'Expand the journal entries to revisit your reflections. Use My Personas to choose another perspective or create a new one.'],
    paused: ['A moment of stillness', 'Your last accepted journey step is kept so you can return when ready.', 'Choose Resume the journey to continue from your saved place.'],
    'state-view': ['Explore a tile or hexagram', 'Read the meaning, symbolic associations, and available context of the selected experience tile or hexagram.', 'Follow the reference controls to explore further, or close the state view to return to your journey.'],
    yarrow: ['The yarrow ceremony', 'Explore the six-line casting ceremony on its own.', 'Choose Continue to advance through each stalk step and build the hexagram from bottom to top. Return to the journey using the link above.'],
    prototype: ['Journey prototype', 'This diagnostic page provides the earlier journey controls for saved prototype castings.', 'Sign in to inspect or continue a prototype journey, or follow the journey interface link to create or select a Persona.'],
    lab: ['Interpretation lab', 'Explore the relationship between a primary and resulting hexagram and a question about a Leela state.', 'Enter the King Wen numbers, your question, and a Leela state. Choose Preview casting to inspect the pair, or Request interpretation to request a reading.'],
    'admin-login': ['Administrator sign in', 'Access the private, read-only usage dashboard.', 'Enter the administrator password and choose Continue. First-time setup also requires the configured one-time setup secret.'],
    admin: ['Usage dashboard', 'Review player participation, casting totals, and movement activity.', 'Choose a reporting period, use Refresh for current data, and use Previous or Next to browse players. Sign out when finished.'],
    landing: ['Play or read', 'Choose how you would like to explore the Tao of Leela.', 'Follow Play to begin a journey, or Read to explore the introduction and user manual.'],
    reading: ['The reading room', 'Explore the ideas behind Leela and practical guidance for your journey.', 'Choose the introduction or user manual, or follow Play Leela to begin.'],
    introduction: ['An invitation to Leela', 'Discover the contemplative ideas behind Leela, the Book of Changes, and personal reflection.', 'Read at your own pace, open the user manual for practical steps, or follow Play Leela to begin.'],
    guide: ['Your first journey', 'Learn how to create a Persona, ask a question, cast, reflect, and continue your journey.', 'Follow the guide in order or use its links to find a topic. Choose Play Leela when you are ready to practise.'],
    missing: ['Find your way back', 'The requested reading page could not be found.', 'Choose Return to the reading room to find the introduction and user manual.']
  };
  guidance.result = guidance.interpretation;
  let current = document.body.dataset.screenInfo || 'splash';
  let dialog;
  const buttonMarkup = key => `<button type="button" class="leela-info-button" data-screen-info-key="${key}" aria-label="Info about this screen" aria-haspopup="dialog" title="About this screen"><svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 11v6" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="7.5" r="1" fill="currentColor"/></svg></button>`;
  const host = document.querySelector('[data-screen-info-host]') || (() => {
    const bar = document.createElement('div');
    bar.className = 'leela-info-bar';
    document.body.prepend(bar);
    return bar;
  })();
  host.insertAdjacentHTML('afterbegin', buttonMarkup(current));
  const primaryButton = host.querySelector('[data-screen-info-key]');
  function close() { if (dialog?.open) dialog.close(); }
  function update(key) {
    if (key !== current) close();
    current = Object.hasOwn(guidance, key) ? key : 'splash';
    primaryButton.dataset.screenInfoKey = current;
  }
  function open(key, trigger) {
    if (dialog?.open) return;
    const [title, purpose, next] = guidance[key] || guidance[current];
    dialog = document.createElement('dialog');
    const activeDialog = dialog;
    dialog.className = 'leela-info-dialog';
    dialog.setAttribute('aria-labelledby', 'leela-info-title');
    dialog.setAttribute('aria-describedby', 'leela-info-purpose leela-info-next');
    const heading = document.createElement('h2');
    heading.id = 'leela-info-title'; heading.textContent = title;
    const description = document.createElement('p');
    description.id = 'leela-info-purpose'; description.textContent = purpose;
    const nextHeading = document.createElement('h3'); nextHeading.textContent = 'How to continue';
    const nextStep = document.createElement('p');
    nextStep.id = 'leela-info-next'; nextStep.textContent = next;
    const dismiss = document.createElement('button');
    dismiss.type = 'button'; dismiss.textContent = 'Close'; dismiss.autofocus = true;
    dismiss.addEventListener('click', close);
    dialog.append(heading, description, nextHeading, nextStep, dismiss);
    dialog.addEventListener('close', () => {
      activeDialog.remove();
      if (dialog === activeDialog) dialog = null;
      if (trigger?.isConnected) trigger.focus({preventScroll: true});
    }, {once: true});
    dialog.addEventListener('click', event => {
      if (event.target !== activeDialog) return;
      const r = activeDialog.getBoundingClientRect();
      if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) close();
    });
    document.body.append(dialog);
    dialog.showModal();
  }
  document.addEventListener('click', event => {
    const button = event.target.closest('[data-screen-info-key]');
    if (!button) return;
    event.preventDefault();
    open(button.dataset.screenInfoKey, button);
  });
  window.LeelaScreenInfo = {update, buttonMarkup};
})();
