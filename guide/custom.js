// Proxy URL converter
const PROXY_HOST = 'unifi.gryzlov.com';
const ALLOWED_DOMAINS = [
    'fw-download.ubnt.com',
    'fw-update.ubnt.com',
    'fw-update.ui.com',
    'fw-download.ui.com',
    'apt.artifacts.ui.com',
    'apt-release-candidate.artifacts.ui.com',
    'apt-beta.artifacts.ui.com'
];

let convertedUrl = '';

function convertUrl() {
    const input = document.getElementById('original-url').value.trim();
    const error = document.getElementById('error-message');
    const copyBtn = document.getElementById('copy-btn');
    const downloadBtn = document.getElementById('download-btn');

    error.textContent = '';
    convertedUrl = '';

    if (!input) {
        copyBtn.disabled = true;
        downloadBtn.disabled = true;
        return;
    }

    let url;
    try {
        url = new URL(input);
    } catch (e) {
        error.textContent = 'Некорректная ссылка';
        copyBtn.disabled = true;
        downloadBtn.disabled = true;
        return;
    }

    if (!ALLOWED_DOMAINS.includes(url.hostname)) {
        error.textContent = 'Домен не поддерживается. Разрешены: ' + ALLOWED_DOMAINS.join(', ');
        copyBtn.disabled = true;
        downloadBtn.disabled = true;
        return;
    }

    // Convert: https://domain/path -> https://proxy/domain/path
    convertedUrl = 'https://' + PROXY_HOST + '/' + url.hostname + url.pathname + url.search;
    copyBtn.disabled = false;
    downloadBtn.disabled = false;
}

function copyUrl() {
    navigator.clipboard.writeText(convertedUrl).then(() => {
        const btn = document.getElementById('copy-btn');
        const original = btn.textContent;
        btn.textContent = 'Скопировано!';
        setTimeout(() => btn.textContent = original, 2000);
    });
}

function downloadFile() {
    const a = document.createElement('a');
    a.href = convertedUrl;
    a.download = '';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}

// Плагин: кнопка копирования для inline-code
const inlineCodeCopyPlugin = function(hook) {
    // Создаём элемент feedback один раз
    hook.ready(function() {
        if (!document.querySelector('.copy-feedback')) {
            const feedback = document.createElement('div');
            feedback.classList.add('copy-feedback');
            feedback.textContent = 'Скопировано';
            document.body.appendChild(feedback);
        }
    });

    hook.doneEach(function() {
        const inlineCodes = Array.from(document.querySelectorAll('code'))
            .filter((code) => !code.closest('pre'));

        inlineCodes.forEach((code) => {
            const wrapperAlready = code.parentElement && code.parentElement.classList.contains('inline-code-wrap');
            if (wrapperAlready) {
                return;
            }

            const wrapper = document.createElement('span');
            wrapper.classList.add('inline-code-wrap');

            code.parentNode.insertBefore(wrapper, code);
            wrapper.appendChild(code);

            const button = document.createElement('button');
            button.type = 'button';
            button.classList.add('inline-copy-btn');
            button.setAttribute('aria-label', 'Скопировать');

            const icon = document.createElement('img');
            icon.src = 'copy.svg';
            icon.alt = 'Copy';
            icon.classList.add('copy-icon');

            button.appendChild(icon);
            wrapper.appendChild(button);

            function doCopy() {
                const textToCopy = code.textContent;
                navigator.clipboard.writeText(textToCopy).then(() => {
                    button.classList.add('is-copied');
                    setTimeout(() => button.classList.remove('is-copied'), 1200);

                    // Показываем feedback
                    const feedback = document.querySelector('.copy-feedback');
                    feedback.classList.remove('show');
                    void feedback.offsetWidth; // reflow для перезапуска анимации
                    feedback.classList.add('show');
                });
            }

            button.addEventListener('click', function(event) {
                event.preventDefault();
                event.stopPropagation();
                doCopy();
            });

            // Клик по всему блоку — копируем, если нет выделения
            wrapper.addEventListener('click', function(event) {
                if (event.target === button || event.target === icon) return;
                const selection = window.getSelection().toString();
                if (!selection) {
                    doCopy();
                }
            });
        });
    });
};

// Склонение слов: 1 консоль, 2 консоли, 5 консолей
function pluralize(n, one, few, many) {
    const mod10 = n % 10;
    const mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 19) return many;
    if (mod10 === 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
}

// Плагин: статистика использования
const statsPlugin = function(hook) {
    hook.doneEach(function() {
        const container = document.getElementById('usage-stats');
        const devicesEl = document.getElementById('stat-devices');
        const devicesLabelEl = document.getElementById('stat-devices-label');
        const downloadsEl = document.getElementById('stat-downloads');
        const downloadsLabelEl = document.getElementById('stat-downloads-label');
        const sizeEl = document.getElementById('stat-size');

        if (!container || !devicesEl || !sizeEl) return;

        fetch('https://' + PROXY_HOST + '/guide/stats.json')
            .then(r => r.json())
            .then(data => {
                if (!data.unique_ips && !data.total_mb) {
                    container.style.display = 'none';
                    return;
                }

                const ips = data.unique_ips || 0;
                const downloads = data.downloads_total || 0;
                const mb = data.total_mb || 0;
                const gb = (mb / 1024).toFixed(1);

                devicesEl.textContent = ips;
                if (devicesLabelEl) {
                    devicesLabelEl.textContent = pluralize(ips, 'консоль', 'консоли', 'консолей');
                }

                if (downloadsEl) {
                    downloadsEl.textContent = downloads;
                }
                if (downloadsLabelEl) {
                    downloadsLabelEl.textContent = pluralize(downloads, 'прошивка', 'прошивки', 'прошивок');
                }

                sizeEl.textContent = gb;

                container.style.display = 'flex';
            })
            .catch(() => {
                container.style.display = 'none';
            });
    });
};

window.$docsify = window.$docsify || {};
window.$docsify.plugins = (window.$docsify.plugins || []).concat(inlineCodeCopyPlugin, statsPlugin);
