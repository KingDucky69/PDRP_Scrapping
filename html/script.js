// Minimal, robust NUI implementation
// Local image map (prefer .webp; fallback to placeholder SVG).
function localImageUrl(modelKey) {
  return `images/${modelKey}.webp`;
}

let open = false;
const app = document.getElementById('app');
const grid = document.getElementById('grid');
const closeBtn = document.getElementById('closeBtn');
const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pdrp_scrapping';

function postNUI(event, data) {
  try {
    fetch(`https://${resourceName}/${event}`, {
      method: 'POST',
      body: data ? JSON.stringify(data) : '{}'
    }).catch(() => {});
  } catch (_) {}
}

function show(vehicleData, playerStats) {
  if (open) return;
  grid.innerHTML = '';

  // Update player stats if provided
  if (playerStats) {
    updatePlayerStats(playerStats);
  }

  const playerLevel = playerStats ? playerStats.level : 1;

  if (!Array.isArray(vehicleData) || vehicleData.length === 0) {
    grid.innerHTML = '<div class="panel-footer">No vehicles available today.</div>';
  } else {
    for (const vehicleInfo of vehicleData) {
      // Handle both old format (string) and new format (object)
      let modelKey, requiredLevel, tier, isUnlocked;
      
      if (typeof vehicleInfo === 'string') {
        // Legacy format - just vehicle name
        modelKey = vehicleInfo.toLowerCase();
        requiredLevel = 1;
        tier = 1;
        isUnlocked = true;
      } else {
        // New format with tier info
        modelKey = vehicleInfo.model.toLowerCase();
        requiredLevel = vehicleInfo.requiredLevel || 1;
        tier = vehicleInfo.tier || 1;
        isUnlocked = vehicleInfo.isUnlocked !== false;
      }
      
      const nice = modelKey.charAt(0).toUpperCase() + modelKey.slice(1);

      const card = document.createElement('div');
      card.className = isUnlocked ? 'card' : 'card locked';

      const imgWrap = document.createElement('div');
      imgWrap.className = 'img-wrap';
      const imgEl = document.createElement('img');
      const urls = [localImageUrl(modelKey), 'images/_placeholder.svg'];
      let idx = 0;
      imgEl.alt = nice;
      imgEl.src = urls[idx];
      imgEl.onerror = () => {
        idx++;
        if (idx < urls.length) imgEl.src = urls[idx];
      };
      imgWrap.appendChild(imgEl);

      const nameEl = document.createElement('div');
      nameEl.className = 'name';
      nameEl.textContent = nice;

      // Add level requirement info
      const levelInfo = document.createElement('div');
      levelInfo.className = 'level-info';
      
      if (!isUnlocked) {
        levelInfo.innerHTML = `<span class="level-required">Level ${requiredLevel} Required</span>`;
        levelInfo.classList.add('locked-info');
      } else {
        levelInfo.innerHTML = `<span class="tier-badge tier-${tier}">Tier ${tier}</span>`;
      }

      card.appendChild(imgWrap);
      card.appendChild(nameEl);
      card.appendChild(levelInfo);
      grid.appendChild(card);
    }
  }

  app.classList.remove('hidden');
  open = true;
}

function updatePlayerStats(stats) {
  const playerLevel = document.getElementById('playerLevel');
  const currentXP = document.getElementById('currentXP');
  const nextLevelXP = document.getElementById('nextLevelXP');
  const xpToNext = document.getElementById('xpToNext');
  const xpFill = document.getElementById('xpFill');

  if (playerLevel) playerLevel.textContent = stats.level || 1;
  if (currentXP) currentXP.textContent = stats.currentXP || 0;
  if (nextLevelXP) nextLevelXP.textContent = stats.nextLevelXP || 100;
  if (xpToNext) xpToNext.textContent = stats.xpToNext || 100;
  
  if (xpFill) {
    const progress = stats.levelProgress || 0;
    xpFill.style.width = `${Math.min(100, Math.max(0, progress))}%`;
  }
}

function hide() {
  if (!open) return;
  app.classList.add('hidden');
  open = false;
  // Notify client to release focus (use simple callback name for compatibility)
  postNUI('close');
}

closeBtn.addEventListener('click', hide);
document.addEventListener('keydown', (e) => {
  if (open && (e.key === 'Escape' || e.key === 'Esc')) hide();
});

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type === 'showUI') show(data.vehicles || [], data.playerStats);
  if (data.type === 'hideUI') hide();
  if (data.type === 'updateStats') updatePlayerStats(data.playerStats);
  // progress handled via ox_lib on client now
});

// No custom GetParentResourceName here; we rely on the FiveM-provided function when available.

// No NUI progress overlay (using ox_lib on client)