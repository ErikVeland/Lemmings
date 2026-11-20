const gallery = document.querySelector('[data-gallery]');
if (gallery) {
  const controls = gallery.querySelector('.capture-tabs');
  const buttons = [...controls.querySelectorAll('button[data-capture]')];
  const figures = gallery.querySelectorAll('[data-platform]');

  function select(platform) {
    gallery.dataset.active = platform;
    for (const figure of figures) figure.hidden = figure.dataset.platform !== platform;
    for (const button of buttons) {
      button.setAttribute('aria-pressed', String(button.dataset.capture === platform));
    }
  }

  for (const button of buttons) {
    button.addEventListener('click', () => select(button.dataset.capture));
  }
  select(buttons[0].dataset.capture);
  controls.hidden = false;
}
