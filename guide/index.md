## <img src="images/favicon.png" width="40" height="40" id="logo"> Обновление UniFi

Сервис помогает пользователям UniFi обновлять свое оборудование, обходя ограничения на загрузку обновлений со стороны Ubiquiti. Соблюдая законы США, производитель блокирует доступ двумя способами — через DNS-заглушки и проверку IP-адресов на CDN.

Мой прокси принимает запросы на себя и перенаправляет их через Албанию, позволяя обойти обе блокировки одновременно.

<navi>
  <a href="#/automatic">
  <card>
    <card-title>🔄 &nbsp;Автоматически</card-title>
    Настройка DNS для прозрачного проксирования
  </card>
  </a>

  <a href="#/manual">
  <card>
    <card-title>📥 &nbsp;Вручную</card-title>
    Помощник для скачивания прошивок вручную без VPN
  </card>
  </a>
</navi>


---

### 🔒 Это безопасно?

Я использую этот сервис лично для своего оборудования и для оборудования друзей. Код проекта открыт, описание того, как он работает и как создать такой же сервер — доступно на [GitHub](https://github.com/spinogrizz/unifi-proxy).

Статистика ниже обновляется каждый час на основе логов nginx, из которых видно уникальные IP адреса консолей (роутеров), которые обновлялись, количество и размер скачанных обновлений:

<div id="usage-stats" style="display:none">
    <div class="stat-card">
        <div class="stat-number" id="stat-devices">—</div>
        <div class="stat-label"><span id="stat-devices-label">IP адресов</span> за 48 часов</div>
    </div>
    <div class="stat-card">
        <div class="stat-number" id="stat-downloads">—</div>
        <div class="stat-label"><span id="stat-downloads-label">обновлений</span> скачано</div>
    </div>
    <div class="stat-card">
        <div class="stat-number"><span id="stat-size">—</span><span class="stat-unit"> ГБ</span></div>
        <div class="stat-label">трафик за все время</div>
    </div>
</div>




<style>

#logo {
    vertical-align: middle;
    margin-right: 10px;
    position: relative;
    top: -2px;
}

navi a {
    text-decoration: none !important;
}

navi {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1.25rem;
    margin: 2rem 0;
    width: 100%;
    max-width: 56rem;
}

@media (min-width: 640px) {
    navi {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (min-width: 960px) {
    navi {
        grid-template-columns: repeat(3, 1fr);
    }
}

card {
    display: block;
    padding: 1.5rem;
    border-radius: 10px;
    transition: all 0.25s ease;
    border: 1px solid transparent;
    height: 100%;
    box-sizing: border-box;
}

card-title {
    display: block;
    margin-top: 0;
    margin-bottom: 0.6rem;
    font-size: 1.15rem;
    font-weight: 600;
    color: inherit;
}

card:not(:only-of-type) {
    font-size: 0.95rem;
    line-height: 1.5;
}

@media (prefers-color-scheme: light) {
    card {
        background-color: #f5f5f5;
        border-color: #e0e0e0;
    }
    
    card:hover {
        background-color: #f0f0f0;
        border-color: #d0d0d0;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    }
}

@media (prefers-color-scheme: dark) {
    card {
        background-color: rgb(30, 30, 30);
        border-color: rgb(50, 50, 50);
    }
    
    card:hover {
        background-color: rgb(35, 35, 35);
        border-color: rgb(60, 60, 60);
        box-shadow: 0 4px 12px rgba(255, 255, 255, 0.08);
    }
}

/* Статистика использования */
#usage-stats {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    margin: 1.5rem 0;
    padding: 0 !important;
    background: transparent !important;
}

.stat-card {
    min-width: 185px;
    padding: 1.25rem 1.5rem 1rem 1.25rem;
    border-radius: 10px;
}

@media (max-width: 640px) {
    #usage-stats {
        flex-direction: column;
    }

    .stat-card {
        min-width: auto;
        width: 100%;
    }
}

.stat-number {
    font-size: 2.5rem;
    font-weight: 700;
    line-height: 1.1;
    letter-spacing: -0.02em;
}

.stat-unit {
    font-size: 1.5rem;
    font-weight: 500;
    margin-left: 0.1em;
}

.stat-label {
    font-size: 0.85rem;
    margin-top: 0.4rem;
    opacity: 0.6;
}

@media (prefers-color-scheme: light) {
    .stat-card {
        background-color: #f5f5f5;
        border: 1px solid #e0e0e0;
    }
}

@media (prefers-color-scheme: dark) {
    .stat-card {
        background-color: rgb(30, 30, 30);
        border: 1px solid rgb(50, 50, 50);
    }
}
</style>