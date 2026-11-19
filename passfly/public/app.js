'use strict';

const $ = (id) => document.getElementById(id);
const TYPES = ['lowercase', 'uppercase', 'numbers', 'symbols'];
const LEVELS = {
  'débil': { width: '25%', color: '#f87171' },
  media: { width: '50%', color: '#fbbf24' },
  fuerte: { width: '75%', color: '#a3e635' },
  'muy fuerte': { width: '100%', color: '#34d399' },
};

function showError(msg) {
  $('error').textContent = msg;
  $('error').hidden = !msg;
}

async function generate() {
  showError('');
  if (!TYPES.some((t) => $(t).checked)) {
    showError('Selecciona al menos un tipo de carácter.');
    return;
  }
  const body = {
    length: Number($('length').value),
    excludeAmbiguous: $('excludeAmbiguous').checked,
  };
  TYPES.forEach((t) => { body[t] = $(t).checked; });

  try {
    const res = await fetch('/api/v1/passwords', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al generar la contraseña');

    $('password').textContent = data.passwords[0];
    $('copy').disabled = false;
    const level = LEVELS[data.strength];
    $('bar-fill').style.width = level.width;
    $('bar-fill').style.background = level.color;
    $('strength-text').textContent = `${data.strength} · ${data.entropyBits} bits`;
  } catch (err) {
    showError(err.message);
  }
}

$('form').addEventListener('submit', (e) => { e.preventDefault(); generate(); });
$('length').addEventListener('input', () => { $('length-value').textContent = $('length').value; });
$('copy').addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText($('password').textContent);
    $('copy').textContent = '¡Copiado!';
    setTimeout(() => { $('copy').textContent = 'Copiar'; }, 1500);
  } catch {
    showError('No se pudo copiar automáticamente.');
  }
});

generate();
