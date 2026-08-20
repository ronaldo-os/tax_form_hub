// Compact Bento Grid (Clean, High-Density & Modular) Dashboard Module

let performanceTrendChart = null;
let statusDonutChart = null;
let taxComplianceChart = null;

let currentDashboardData = null;
let currentSeriesFilter = 'all';
let currentStatusType = 'sales';
let currentPartnerType = 'customers';

function getThemeColors() {
  const isDark = (document.documentElement.getAttribute('data-theme') || 'light') === 'dark';
  return {
    isDark: isDark,
    textColor: isDark ? '#f8f9fa' : '#1e293b',
    mutedColor: isDark ? '#94a3b8' : '#64748b',
    gridColor: isDark ? 'rgba(255, 255, 255, 0.04)' : 'rgba(0, 0, 0, 0.03)',
    cardBg: isDark ? '#212529' : '#ffffff',
    tooltipBg: isDark ? '#181b1f' : '#0f172a',
    borderColor: isDark ? '#374151' : '#e2e8f0'
  };
}

function formatCurrency(amount, currency = 'USD') {
  const num = parseFloat(amount) || 0;
  const symbol = currency === 'PHP' ? '₱' : (currency === 'EUR' ? '€' : (currency === 'GBP' ? '£' : '$'));
  return symbol + num.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function initAnalyticsDashboard() {
  const container = document.getElementById('analytics_dashboard_container');
  if (!container) return;

  const rawData = container.getAttribute('data-initial-data');
  if (rawData) {
    try {
      currentDashboardData = JSON.parse(rawData);
    } catch (e) {
      console.error('Failed to parse dashboard initial data:', e);
    }
  }

  if (currentDashboardData) {
    renderDashboardCharts(currentDashboardData);
  }

  if (!container.dataset.eventsAttached) {
    setupDashboardEventListeners();
    container.dataset.eventsAttached = 'true';
  }
}

let chartRenderAttempts = 0;
function renderDashboardCharts(data) {
  if (!data || !data.charts) return;

  const trendCanvas = document.getElementById('performanceTrendChart');
  const donutCanvas = document.getElementById('statusDonutChart');

  if (typeof Chart === 'undefined' || !trendCanvas || !donutCanvas) {
    if (chartRenderAttempts < 50) {
      chartRenderAttempts++;
      setTimeout(() => renderDashboardCharts(data), 60);
    }
    return;
  }

  chartRenderAttempts = 0;
  renderPerformanceTrendChart(data.charts.trends, data.currency);
  renderStatusDonutChart(data.charts[currentStatusType === 'sales' ? 'sales_status' : 'purchases_status']);
  renderTaxComplianceChart(data.charts.tax_compliance);
}

function renderPerformanceTrendChart(trends, currency) {
  const ctx = document.getElementById('performanceTrendChart');
  if (!ctx) return;

  if (performanceTrendChart) {
    performanceTrendChart.destroy();
  }

  const colors = getThemeColors();
  const datasets = [];

  if (currentSeriesFilter === 'all' || currentSeriesFilter === 'revenue') {
    datasets.push({
      label: 'Sales Revenue',
      data: trends.revenue || [],
      borderColor: '#10b981',
      backgroundColor: colors.isDark ? 'rgba(16, 185, 129, 0.08)' : 'rgba(16, 185, 129, 0.05)',
      borderWidth: 2,
      fill: true,
      tension: 0.3,
      pointRadius: 2.5,
      pointHoverRadius: 4.5,
      pointBackgroundColor: '#10b981'
    });
  }

  if (currentSeriesFilter === 'all' || currentSeriesFilter === 'expenses') {
    datasets.push({
      label: 'Purchases / Spend',
      data: trends.expenses || [],
      borderColor: colors.isDark ? '#94a3b8' : '#64748b',
      backgroundColor: colors.isDark ? 'rgba(148, 163, 184, 0.06)' : 'rgba(100, 116, 139, 0.04)',
      borderWidth: 2,
      fill: true,
      tension: 0.3,
      pointRadius: 2.5,
      pointHoverRadius: 4.5,
      pointBackgroundColor: colors.isDark ? '#94a3b8' : '#64748b'
    });
  }

  if (currentSeriesFilter === 'all' || currentSeriesFilter === 'net') {
    datasets.push({
      label: 'Net Flow',
      data: trends.net_flow || [],
      borderColor: '#0ea5e9',
      backgroundColor: 'transparent',
      borderWidth: 1.5,
      borderDash: [4, 4],
      fill: false,
      tension: 0.3,
      pointRadius: 2,
      pointHoverRadius: 4,
      pointBackgroundColor: '#0ea5e9'
    });
  }

  performanceTrendChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: trends.labels || [],
      datasets: datasets
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false
      },
      plugins: {
        legend: {
          display: true,
          position: 'top',
          align: 'end',
          labels: {
            color: colors.mutedColor,
            font: { family: 'Roboto, sans-serif', size: 10.5 },
            usePointStyle: true,
            boxWidth: 6,
            padding: 10
          }
        },
        tooltip: {
          backgroundColor: colors.tooltipBg,
          titleColor: '#ffffff',
          bodyColor: '#e2e8f0',
          borderColor: colors.borderColor,
          borderWidth: 1,
          padding: 8,
          boxPadding: 4,
          cornerRadius: 6,
          callbacks: {
            label: function (context) {
              const label = context.dataset.label || '';
              return ` ${label}: ${formatCurrency(context.parsed.y, currency)}`;
            }
          }
        }
      },
      scales: {
        x: {
          grid: { color: colors.gridColor, drawBorder: false },
          ticks: { color: colors.mutedColor, font: { size: 10 } }
        },
        y: {
          grid: { color: colors.gridColor, drawBorder: false },
          ticks: {
            color: colors.mutedColor,
            font: { size: 10 },
            callback: function (val) {
              return formatCurrency(val, currency);
            }
          }
        }
      }
    }
  });
}

function renderStatusDonutChart(statusCounts) {
  const ctx = document.getElementById('statusDonutChart');
  if (!ctx) return;

  if (statusDonutChart) {
    statusDonutChart.destroy();
  }

  const colors = getThemeColors();
  const counts = statusCounts || {};

  const labels = ['Paid', 'Approved', 'Sent', 'Pending', 'Draft', 'Rejected'];
  const values = [
    counts.paid || 0,
    counts.approved || 0,
    counts.sent || 0,
    counts.pending || 0,
    counts.draft || 0,
    counts.rejected || 0
  ];

  const totalCount = values.reduce((a, b) => a + b, 0);

  const backgroundColors = [
    '#10b981', // Paid
    '#00aeff', // Approved
    '#38bdf8', // Sent
    '#f59e0b', // Pending
    '#94a3b8', // Draft
    '#ef4444'  // Rejected
  ];

  statusDonutChart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: labels,
      datasets: [{
        data: totalCount === 0 ? [1] : values,
        backgroundColor: totalCount === 0 ? ['#e2e8f0'] : backgroundColors,
        borderWidth: 1.5,
        borderColor: colors.cardBg,
        hoverOffset: 3
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: '74%',
      plugins: {
        legend: {
          position: 'bottom',
          labels: {
            color: colors.mutedColor,
            font: { size: 10 },
            usePointStyle: true,
            boxWidth: 6,
            padding: 8
          }
        },
        tooltip: {
          backgroundColor: colors.tooltipBg,
          titleColor: '#ffffff',
          bodyColor: '#e2e8f0',
          borderColor: colors.borderColor,
          borderWidth: 1,
          cornerRadius: 6,
          padding: 8,
          callbacks: {
            label: function (context) {
              if (totalCount === 0) return ' No records';
              const count = context.parsed;
              const pct = totalCount > 0 ? Math.round((count / totalCount) * 100) : 0;
              return ` ${context.label}: ${count} (${pct}%)`;
            }
          }
        }
      }
    }
  });
}

function renderTaxComplianceChart(taxData) {
  const ctx = document.getElementById('taxComplianceChart');
  if (!ctx) return;

  if (taxComplianceChart) {
    taxComplianceChart.destroy();
  }

  const colors = getThemeColors();
  const d = taxData || { processed: 0, reviewed: 0, pending: 0 };
  const total = (d.processed || 0) + (d.reviewed || 0) + (d.pending || 0);

  taxComplianceChart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: ['Processed & Filed', 'Reviewed', 'Pending Review'],
      datasets: [{
        data: total === 0 ? [1] : [d.processed || 0, d.reviewed || 0, d.pending || 0],
        backgroundColor: total === 0
          ? [colors.isDark ? '#374151' : '#e2e8f0']
          : ['#10b981', '#0ea5e9', '#f59e0b'],
        borderWidth: 0,
        hoverOffset: 3
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: '78%',
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: colors.tooltipBg,
          titleColor: '#ffffff',
          bodyColor: '#e2e8f0',
          borderColor: colors.borderColor,
          borderWidth: 0,
          cornerRadius: 6,
          padding: 8,
          callbacks: {
            label: function (context) {
              if (total === 0) return ' No submissions';
              const count = context.parsed;
              const pct = total > 0 ? Math.round((count / total) * 100) : 0;
              return ` ${context.label}: ${count} (${pct}%)`;
            }
          }
        }
      }
    }
  });
}

function setupDashboardEventListeners() {
  // 1. Timeframe Filter Group Click
  const timeframeGroup = document.getElementById('dashboard_timeframe_group');
  if (timeframeGroup) {
    timeframeGroup.querySelectorAll('button[data-time-frame]').forEach(btn => {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        const tf = this.getAttribute('data-time-frame');
        timeframeGroup.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        fetchUpdatedAnalyticsData(tf, currentDashboardData ? currentDashboardData.currency : 'all');
      });
    });
  }

  // 2. Currency Selector Click
  document.querySelectorAll('.currency-select-item').forEach(item => {
    item.addEventListener('click', function (e) {
      e.preventDefault();
      const curr = this.getAttribute('data-currency');
      const label = document.getElementById('selected_currency_label');
      if (label) label.textContent = curr.toUpperCase();

      document.querySelectorAll('.currency-select-item').forEach(i => i.classList.remove('active', 'fw-bold'));
      this.classList.add('active', 'fw-bold');

      const activeTimeBtn = document.querySelector('#dashboard_timeframe_group button.active');
      const tf = activeTimeBtn ? activeTimeBtn.getAttribute('data-time-frame') : 'this_month';
      fetchUpdatedAnalyticsData(tf, curr);
    });
  });

  // 3. Trend Series Toggle
  const seriesToggle = document.getElementById('trend_series_toggle');
  if (seriesToggle) {
    seriesToggle.querySelectorAll('button[data-series]').forEach(btn => {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        seriesToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        currentSeriesFilter = this.getAttribute('data-series');
        if (currentDashboardData && currentDashboardData.charts) {
          renderPerformanceTrendChart(currentDashboardData.charts.trends, currentDashboardData.currency);
        }
      });
    });
  }

  // 4. Status Donut Chart Type Toggle
  document.querySelectorAll('.status-chart-type-item').forEach(item => {
    item.addEventListener('click', function (e) {
      e.preventDefault();
      currentStatusType = this.getAttribute('data-type');
      const label = document.getElementById('status_chart_view_label');
      if (label) label.textContent = currentStatusType === 'sales' ? 'Sales Invoices' : 'Purchase Bills';

      document.querySelectorAll('.status-chart-type-item').forEach(i => i.classList.remove('active'));
      this.classList.add('active');

      if (currentDashboardData && currentDashboardData.charts) {
        renderStatusDonutChart(currentDashboardData.charts[currentStatusType === 'sales' ? 'sales_status' : 'purchases_status']);
      }
    });
  });

  // 5. Partner Ranking Toggle
  const partnerToggle = document.getElementById('partner_ranking_toggle');
  if (partnerToggle) {
    partnerToggle.querySelectorAll('button[data-partner-type]').forEach(btn => {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        partnerToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        currentPartnerType = this.getAttribute('data-partner-type');
        if (currentDashboardData && currentDashboardData.charts) {
          updatePartnerRankingsUI(currentDashboardData.charts[currentPartnerType === 'customers' ? 'top_customers' : 'top_vendors'], currentDashboardData.currency);
        }
      });
    });
  }

  // 6. Theme Change Listener
  window.addEventListener('themeChanged', function () {
    if (currentDashboardData) {
      renderDashboardCharts(currentDashboardData);
    }
  });

  const observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      if (mutation.attributeName === 'data-theme' || mutation.attributeName === 'data-bs-theme') {
        if (currentDashboardData) {
          renderDashboardCharts(currentDashboardData);
        }
      }
    });
  });
  observer.observe(document.documentElement, { attributes: true });
}

function fetchUpdatedAnalyticsData(timeFrame, currency) {
  const loader = document.getElementById('trend_chart_loader');
  if (loader) loader.classList.add('active');

  const url = `/dashboards/analytics_data?time_frame=${encodeURIComponent(timeFrame)}&currency=${encodeURIComponent(currency)}`;

  fetch(url, {
    headers: {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest'
    }
  })
    .then(response => {
      if (!response.ok) throw new Error('Network response was not ok');
      return response.json();
    })
    .then(data => {
      currentDashboardData = data;
      updateKPICardsUI(data.kpis, data.currency);
      renderDashboardCharts(data);
      updatePartnerRankingsUI(data.charts[currentPartnerType === 'customers' ? 'top_customers' : 'top_vendors'], data.currency);
      updateRecentTransactionsTable(data.recent_invoices, data.currency);
      updateUrgentActionsUI(data.urgent_actions);

      const subtitle = document.getElementById('trend_chart_subtitle');
      if (subtitle && data.range_label) {
        subtitle.textContent = data.range_label;
      }
    })
    .catch(error => {
      console.error('Error fetching analytics data:', error);
    })
    .finally(() => {
      if (loader) loader.classList.remove('active');
    });
}

function updateKPICardsUI(kpis, currency) {
  if (!kpis) return;

  // 1. Total Sales Revenue & Sub-metrics
  const salesRevVal = document.getElementById('kpi_sales_revenue_val');
  if (salesRevVal) salesRevVal.textContent = formatCurrency(kpis.total_sales_revenue, currency);

  const salesGrowthTag = document.getElementById('kpi_sales_growth_tag');
  if (salesGrowthTag) {
    salesGrowthTag.className = `bento-trend ${kpis.sales_revenue_growth >= 0 ? 'bento-trend-up' : 'bento-trend-down'}`;
    salesGrowthTag.innerHTML = `<i class="fa-solid ${kpis.sales_revenue_growth >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'} fs-10"></i> ${Math.abs(kpis.sales_revenue_growth)}%`;
  }

  const salesCollRate = document.getElementById('kpi_sales_coll_rate');
  if (salesCollRate) salesCollRate.textContent = `${kpis.sales_collection_rate}%`;

  const salesCollBar = document.getElementById('kpi_sales_coll_bar');
  if (salesCollBar) salesCollBar.style.width = `${Math.min(kpis.sales_collection_rate, 100)}%`;

  const paidSalesRev = document.getElementById('kpi_paid_sales_rev');
  if (paidSalesRev) paidSalesRev.textContent = formatCurrency(kpis.paid_sales_revenue, currency);

  const salesReceivables = document.getElementById('kpi_sales_receivables');
  if (salesReceivables) salesReceivables.textContent = formatCurrency(kpis.total_receivables, currency);

  const avgSaleVal = document.getElementById('kpi_avg_sale_val');
  if (avgSaleVal) avgSaleVal.textContent = formatCurrency(kpis.avg_sale_invoice_value, currency);

  // 2. Total Purchases / Spend & Sub-metrics
  const purchExpVal = document.getElementById('kpi_purchases_expense_val');
  if (purchExpVal) purchExpVal.textContent = formatCurrency(kpis.total_purchases_expense, currency);

  const purchGrowthTag = document.getElementById('kpi_purchases_growth_tag');
  if (purchGrowthTag) {
    purchGrowthTag.className = `bento-trend ${kpis.purchases_growth <= 0 ? 'bento-trend-up' : 'bento-trend-down'}`;
    purchGrowthTag.innerHTML = `<i class="fa-solid ${kpis.purchases_growth >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'} fs-10"></i> ${Math.abs(kpis.purchases_growth)}%`;
  }

  const purchSettleRate = document.getElementById('kpi_purch_settle_rate');
  if (purchSettleRate) purchSettleRate.textContent = `${kpis.purchases_settlement_rate}%`;

  const purchSettleBar = document.getElementById('kpi_purch_settle_bar');
  if (purchSettleBar) purchSettleBar.style.width = `${Math.min(kpis.purchases_settlement_rate, 100)}%`;

  const paidPurchExp = document.getElementById('kpi_paid_purch_exp');
  if (paidPurchExp) paidPurchExp.textContent = formatCurrency(kpis.paid_purchases_expense, currency);

  const purchPayables = document.getElementById('kpi_purch_payables');
  if (purchPayables) purchPayables.textContent = formatCurrency(kpis.total_payables, currency);

  const avgPurchVal = document.getElementById('kpi_avg_purch_val');
  if (avgPurchVal) avgPurchVal.textContent = formatCurrency(kpis.avg_purchase_bill_value, currency);

  // 3. Net Operating Profit & Margin
  const netIncomeVal = document.getElementById('kpi_net_income_val');
  if (netIncomeVal) {
    netIncomeVal.textContent = formatCurrency(kpis.net_operating_income, currency);
    netIncomeVal.className = `bento-value bento-financial-value tabular-nums text-truncate ${kpis.net_operating_income >= 0 ? 'text-success' : 'text-danger'}`;
  }

  const profitMarginTag = document.getElementById('kpi_profit_margin_tag');
  if (profitMarginTag) {
    profitMarginTag.className = `bento-chip ${kpis.profit_margin >= 0 ? 'bento-chip-paid' : 'bento-chip-rejected'} fs-10`;
    profitMarginTag.textContent = `${kpis.profit_margin}% Margin`;
  }

  const profitMarginBar = document.getElementById('kpi_profit_margin_bar');
  if (profitMarginBar) {
    profitMarginBar.className = `partner-progress-fill ${kpis.profit_margin >= 0 ? 'bg-success' : 'bg-danger'}`;
    profitMarginBar.style.width = `${Math.min(Math.max(Math.abs(kpis.profit_margin), 0), 100)}%`;
  }

  const netCashFlow = document.getElementById('kpi_net_cash_flow');
  if (netCashFlow) {
    netCashFlow.textContent = formatCurrency(kpis.net_cash_flow, currency);
    netCashFlow.className = `fw-semibold ${kpis.net_cash_flow >= 0 ? 'text-success' : 'text-danger'} fs-9 tabular-nums`;
  }

  const netCashFlowSub = document.getElementById('kpi_net_cash_flow_sub');
  if (netCashFlowSub) {
    netCashFlowSub.textContent = formatCurrency(kpis.net_cash_flow, currency);
    netCashFlowSub.className = `substat-value ${kpis.net_cash_flow >= 0 ? 'text-success' : 'text-danger'} tabular-nums`;
  }

  const workingCap = document.getElementById('kpi_working_capital');
  if (workingCap) workingCap.textContent = formatCurrency(kpis.net_working_capital, currency);

  const netGrowth = document.getElementById('kpi_net_growth');
  if (netGrowth) {
    netGrowth.textContent = `${kpis.net_income_growth >= 0 ? '+' : ''}${kpis.net_income_growth}%`;
    netGrowth.className = `substat-value ${kpis.net_income_growth >= 0 ? 'text-success' : 'text-danger'} tabular-nums`;
  }

  // 4. Subscriptions & Recurring Revenue (MRR/ARR)
  const mrrVal = document.getElementById('kpi_mrr_val');
  if (mrrVal) {
    mrrVal.innerHTML = `${formatCurrency(kpis.total_mrr, currency)}<span class="fs-9 text-muted fw-normal ms-1">/mo</span>`;
  }

  const arrTag = document.getElementById('kpi_arr_tag');
  if (arrTag) arrTag.textContent = `ARR ${formatCurrency(kpis.total_arr, currency)}`;

  const activeSubsCount = document.getElementById('kpi_active_subs_count');
  if (activeSubsCount) activeSubsCount.textContent = `${kpis.active_subscriptions_count} active`;

  const arpuVal = document.getElementById('kpi_arpu_val');
  if (arpuVal) arpuVal.textContent = formatCurrency(kpis.avg_mrr_per_subscription, currency);

  const taxSalesVal = document.getElementById('kpi_tax_sales_val');
  if (taxSalesVal) taxSalesVal.textContent = formatCurrency(kpis.total_tax_sales, currency);

  const creditNotesTotal = document.getElementById('kpi_credit_notes_total');
  if (creditNotesTotal) creditNotesTotal.textContent = formatCurrency(kpis.credit_notes_total, currency);

  // Operational Ribbon Tiles
  const salesVal = document.getElementById('kpi_sales_count_val');
  if (salesVal) salesVal.textContent = kpis.total_sales_count;

  const paidSalesChip = document.getElementById('kpi_paid_sales_chip');
  if (paidSalesChip) paidSalesChip.textContent = `${kpis.paid_sales_count} Paid`;

  const pendingSales = document.getElementById('kpi_pending_sales');
  if (pendingSales) pendingSales.textContent = `${kpis.pending_sales_count} pending / sent`;

  const purchVal = document.getElementById('kpi_purchases_count_val');
  if (purchVal) purchVal.textContent = kpis.total_purchases_count;

  const paidPurchChip = document.getElementById('kpi_paid_purchases_chip');
  if (paidPurchChip) paidPurchChip.textContent = `${kpis.paid_purchases_count} Paid`;

  const unsettledPurch = document.getElementById('kpi_unsettled_purchases');
  if (unsettledPurch) unsettledPurch.textContent = `${Math.max(kpis.total_purchases_count - kpis.paid_purchases_count, 0)} unsettled`;

  const taxVal = document.getElementById('kpi_tax_count_val');
  if (taxVal) taxVal.textContent = kpis.tax_total_count;

  const taxChip = document.getElementById('kpi_tax_chip');
  if (taxChip) {
    taxChip.className = `bento-chip ${kpis.tax_pending_count > 0 ? 'bento-chip-pending' : 'bento-chip-processed'} fs-10`;
    taxChip.textContent = kpis.tax_pending_count > 0 ? `${kpis.tax_pending_count} Pending` : 'Up to Date';
  }

  const taxProcSub = document.getElementById('kpi_tax_processed_sub');
  if (taxProcSub) taxProcSub.textContent = `${kpis.tax_processed_count} processed (${kpis.tax_compliance_rate}%)`;

  const creditNotesChip = document.getElementById('kpi_credit_notes_chip');
  if (creditNotesChip) creditNotesChip.textContent = `${kpis.credit_notes_count || 0} Notes`;

  const creditNotesVal = document.getElementById('kpi_credit_notes_count_val');
  if (creditNotesVal) creditNotesVal.textContent = kpis.credit_notes_count || 0;

  const creditNotesSub = document.getElementById('kpi_credit_notes_sub');
  if (creditNotesSub) creditNotesSub.textContent = `${formatCurrency(kpis.credit_notes_total || 0, currency)} adjusted`;

  const locVal = document.getElementById('kpi_locations_count_val');
  if (locVal) locVal.textContent = kpis.locations_count || 0;

  const netVal = document.getElementById('kpi_networks_count_val');
  if (netVal) netVal.textContent = kpis.networks_count || 0;

  // Efficiency Health Summary Badges
  const healthColl = document.getElementById('health_collection_rate');
  if (healthColl) healthColl.textContent = `${kpis.sales_collection_rate}%`;

  const healthSettle = document.getElementById('health_settlement_rate');
  if (healthSettle) healthSettle.textContent = `${kpis.purchases_settlement_rate}%`;

  const healthTax = document.getElementById('health_tax_rate');
  if (healthTax) healthTax.textContent = `${kpis.tax_compliance_rate}%`;

  // Tax Compliance Donut Score & Status Chip
  const taxScore = document.getElementById('tax_donut_score');
  if (taxScore) taxScore.textContent = `${kpis.tax_compliance_rate}%`;

  const taxStatusChip = document.getElementById('tax_status_chip');
  if (taxStatusChip) {
    const isPending = kpis.tax_pending_count > 0;
    taxStatusChip.className = `bento-chip ${isPending ? 'bento-chip-pending' : 'bento-chip-paid'} fs-10`;
    taxStatusChip.innerHTML = `<i class="fa-solid ${isPending ? 'fa-triangle-exclamation' : 'fa-check'} fs-11"></i> ${isPending ? `${kpis.tax_pending_count} Pending` : '100% Compliant'}`;
  }

  // Tax Checklist Badges & Progress in Breakdown Card
  const totalTaxSubs = kpis.tax_total_count || 0;
  const procCount = kpis.tax_processed_count || 0;
  const revCount = Math.max((kpis.tax_reviewed_count || 0) - procCount, 0);
  const pendCount = kpis.tax_pending_count || 0;

  const procPct = totalTaxSubs > 0 ? Math.round((procCount / totalTaxSubs) * 100) : 100;
  const revPct = totalTaxSubs > 0 ? Math.round((revCount / totalTaxSubs) * 100) : 0;
  const pendPct = totalTaxSubs > 0 ? Math.round((pendCount / totalTaxSubs) * 100) : 0;

  const badgeProc = document.getElementById('tax_badge_processed');
  if (badgeProc) badgeProc.textContent = procCount;
  const badgeProcPct = document.getElementById('tax_badge_processed_pct');
  if (badgeProcPct) badgeProcPct.textContent = `(${procPct}%)`;
  const barProc = document.getElementById('tax_bar_processed');
  if (barProc) barProc.style.width = `${procPct}%`;

  const badgeRev = document.getElementById('tax_badge_reviewed');
  if (badgeRev) badgeRev.textContent = revCount;
  const badgeRevPct = document.getElementById('tax_badge_reviewed_pct');
  if (badgeRevPct) badgeRevPct.textContent = `(${revPct}%)`;
  const barRev = document.getElementById('tax_bar_reviewed');
  if (barRev) barRev.style.width = `${revPct}%`;

  const badgePend = document.getElementById('tax_badge_pending');
  if (badgePend) {
    badgePend.textContent = pendCount;
    badgePend.className = `fw-bold text-main fs-8 tabular-nums ${pendCount > 0 ? 'text-danger' : ''}`;
  }
  const badgePendPct = document.getElementById('tax_badge_pending_pct');
  if (badgePendPct) badgePendPct.textContent = `(${pendPct}%)`;
  const barPend = document.getElementById('tax_bar_pending');
  if (barPend) {
    barPend.className = `partner-progress-fill ${pendCount > 0 ? 'bg-warning' : 'bg-secondary'}`;
    barPend.style.width = `${pendPct}%`;
  }

  const taxTotalFooter = document.getElementById('tax_total_footer_val');
  if (taxTotalFooter) taxTotalFooter.textContent = totalTaxSubs;

  const taxWithheldFooter = document.getElementById('tax_withheld_footer_val');
  if (taxWithheldFooter) taxWithheldFooter.textContent = formatCurrency(kpis.total_tax_sales || 0, currency);
}

function updatePartnerRankingsUI(partners, currency) {
  const container = document.getElementById('partner_rankings_list');
  if (!container) return;

  container.replaceChildren();

  if (!partners || partners.length === 0) {
    const emptyDiv = document.createElement('div');
    emptyDiv.className = 'text-center py-3 text-muted';
    const small = document.createElement('small');
    small.className = 'fs-8';
    small.textContent = 'No partner transaction volume recorded for this period.';
    emptyDiv.appendChild(small);
    container.appendChild(emptyDiv);
    return;
  }

  partners.forEach((partner, idx) => {
    const item = document.createElement('div');
    item.className = 'partner-rank-item';

    const header = document.createElement('div');
    header.className = 'd-flex align-items-center justify-content-between mb-0.5';

    const left = document.createElement('div');
    left.className = 'd-flex align-items-center gap-2';

    const numSpan = document.createElement('span');
    numSpan.className = 'text-muted fs-9 fw-semibold tabular-nums';
    numSpan.style.width = '14px';
    numSpan.textContent = idx + 1;

    const name = document.createElement('span');
    name.className = 'fw-medium text-main fs-8 text-truncate';
    name.style.maxWidth = '220px';
    name.textContent = partner.name;

    left.appendChild(numSpan);
    left.appendChild(name);

    const right = document.createElement('div');
    right.className = 'text-end';

    const amount = document.createElement('span');
    amount.className = 'fw-semibold text-main fs-8 tabular-nums';
    amount.textContent = formatCurrency(partner.amount, currency);

    const pct = document.createElement('small');
    pct.className = 'text-muted ms-1 fs-9';
    pct.textContent = `(${partner.percentage}%)`;

    right.appendChild(amount);
    right.appendChild(pct);

    header.appendChild(left);
    header.appendChild(right);

    const bar = document.createElement('div');
    bar.className = 'partner-progress-bar';

    const fill = document.createElement('div');
    fill.className = 'partner-progress-fill';
    fill.style.width = `${partner.percentage}%`;

    bar.appendChild(fill);

    item.appendChild(header);
    item.appendChild(bar);

    container.appendChild(item);
  });
}

function updateRecentTransactionsTable(invoices, currency) {
  const tbody = document.getElementById('recent_transactions_table_body');
  if (!tbody) return;

  tbody.replaceChildren();

  if (!invoices || invoices.length === 0) {
    const row = document.createElement('tr');
    const td = document.createElement('td');
    td.setAttribute('colspan', '7');
    td.className = 'text-center py-3 text-muted fs-8';
    td.textContent = 'No recent invoices recorded for this filter.';
    row.appendChild(td);
    tbody.appendChild(row);
    return;
  }

  invoices.forEach(inv => {
    const row = document.createElement('tr');

    // 1. Invoice Number
    const tdNum = document.createElement('td');
    const link = document.createElement('a');
    link.href = `/invoices/${inv.id}`;
    link.className = 'fw-semibold text-main text-decoration-none hover-primary';
    link.textContent = inv.invoice_number;
    tdNum.appendChild(link);
    row.appendChild(tdNum);

    // 2. Type
    const tdType = document.createElement('td');
    const badgeType = document.createElement('span');
    badgeType.className = 'text-muted text-uppercase fs-9 fw-medium';
    badgeType.textContent = inv.invoice_type;
    tdType.appendChild(badgeType);
    row.appendChild(tdType);

    // 3. Counterparty
    const tdParty = document.createElement('td');
    tdParty.className = 'fw-medium text-main text-truncate';
    tdParty.style.maxWidth = '170px';
    const partnerName = inv.invoice_type === 'sale'
      ? (inv.recipient_company?.name || 'Direct Customer')
      : (inv.sale_from?.name || 'Direct Vendor');
    tdParty.textContent = partnerName;
    row.appendChild(tdParty);

    // 4. Issue Date
    const tdDate = document.createElement('td');
    tdDate.className = 'text-muted fs-8 tabular-nums';
    try {
      const d = new Date(inv.issue_date || inv.created_at);
      tdDate.textContent = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    } catch {
      tdDate.textContent = '—';
    }
    row.appendChild(tdDate);

    // 5. Amount
    const tdAmount = document.createElement('td');
    tdAmount.className = 'text-end fw-semibold text-main tabular-nums';
    tdAmount.textContent = formatCurrency(inv.grand_total, inv.currency || currency);
    row.appendChild(tdAmount);

    // 6. Bento Chip Status
    const tdStatus = document.createElement('td');
    tdStatus.className = 'text-center';
    const chip = document.createElement('span');
    let chipClass = 'bento-chip-draft';
    if (inv.status === 'paid') chipClass = 'bento-chip-paid';
    else if (inv.status === 'approved') chipClass = 'bento-chip-approved';
    else if (inv.status === 'sent') chipClass = 'bento-chip-sent';
    else if (inv.status === 'pending') chipClass = 'bento-chip-pending';
    else if (inv.status === 'rejected') chipClass = 'bento-chip-rejected';

    chip.className = `bento-chip ${chipClass} text-capitalize fs-9`;
    chip.textContent = inv.status;
    tdStatus.appendChild(chip);
    row.appendChild(tdStatus);

    // 7. Action
    const tdAction = document.createElement('td');
    tdAction.className = 'text-end';
    const viewBtn = document.createElement('a');
    viewBtn.href = `/invoices/${inv.id}`;
    viewBtn.className = 'btn btn-sm btn-link text-muted p-0 text-decoration-none';
    viewBtn.title = 'View';
    const iconChevron = document.createElement('i');
    iconChevron.className = 'fa-solid fa-chevron-right fs-9';
    viewBtn.appendChild(iconChevron);
    tdAction.appendChild(viewBtn);
    row.appendChild(tdAction);

    tbody.appendChild(row);
  });
}

function updateUrgentActionsUI(actions) {
  const container = document.getElementById('urgent_actions_list');
  const countBadge = document.getElementById('urgent_actions_count');
  if (!container) return;

  if (countBadge) {
    countBadge.textContent = (actions || []).length;
  }

  container.replaceChildren();

  if (!actions || actions.length === 0) {
    const emptyDiv = document.createElement('div');
    emptyDiv.className = 'text-center py-2.5 text-muted';
    const icon = document.createElement('i');
    icon.className = 'fa-solid fa-check fs-4 text-muted mb-0.5 d-block opacity-50';
    const small = document.createElement('small');
    small.className = 'fs-8';
    small.textContent = 'All tasks and reviews are complete.';
    emptyDiv.appendChild(icon);
    emptyDiv.appendChild(small);
    container.appendChild(emptyDiv);
    return;
  }

  actions.forEach(act => {
    const item = document.createElement('div');
    item.className = 'bento-action-item d-flex align-items-center justify-content-between gap-2';

    const left = document.createElement('div');

    const title = document.createElement('h6');
    title.className = 'fw-semibold text-main mb-0 fs-8';
    title.textContent = act.title;

    const desc = document.createElement('small');
    desc.className = 'text-muted fs-9 d-block';
    desc.textContent = act.description;

    left.appendChild(title);
    left.appendChild(desc);

    const btn = document.createElement('a');
    btn.href = act.link_url;
    btn.className = 'btn btn-sm btn-outline-secondary rounded-2 px-2.5 py-0.5 fs-9 text-nowrap fw-medium flex-shrink-0';
    btn.textContent = act.link_text;

    item.appendChild(left);
    item.appendChild(btn);

    container.appendChild(item);
  });
}

document.addEventListener('DOMContentLoaded', initAnalyticsDashboard);
document.addEventListener('turbo:load', initAnalyticsDashboard);
document.addEventListener('turbo:render', initAnalyticsDashboard);

// Auto-execute immediately to catch asynchronous dynamic imports
if (document.readyState === 'complete' || document.readyState === 'interactive') {
  initAnalyticsDashboard();
}
