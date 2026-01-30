
export function initCompanySelector() {
    const input = document.getElementById('company_search_input');
    if (!input) return;

    const hiddenInput = document.getElementById('recipient_company_id');
    const dropdown = document.getElementById('company_search_dropdown');
    const spinner = document.getElementById('company_search_spinner');
    const preview = document.getElementById('recipient-preview');
    const selectorInterface = document.getElementById('company_selector_interface');
    const changeBtn = document.getElementById('change-recipient');

    let debounceTimer;

    // Pre-fetch network list immediately on init
    fetchCompanies('');

    // On focus, show dropdown if not already visible
    input.addEventListener('focus', () => {
        if (input.dataset.loadedDefault === "true") {
            dropdown.classList.remove('d-none');
        } else {
            fetchCompanies('');
        }
    });

    // Use mousedown for faster response than click/focus
    input.addEventListener('mousedown', () => {
        if (input.dataset.loadedDefault === "true") {
            dropdown.classList.remove('d-none');
        }
    });

    input.addEventListener('input', (e) => {
        const value = e.target.value;
        clearTimeout(debounceTimer);

        // reset loaded status if typing
        input.dataset.loadedDefault = "false";

        debounceTimer = setTimeout(() => {
            fetchCompanies(value);
        }, 300);
    });

    const clickHandler = (e) => {
        if (!input.contains(e.target) && !dropdown.contains(e.target)) {
            dropdown.classList.add('d-none');
        }
    };

    // Hide dropdown on click outside
    document.addEventListener('click', clickHandler);

    function fetchCompanies(query) {
        if (spinner) spinner.classList.remove('d-none');

        // If query is empty and we haven't loaded defaults, show a small loading indicator in dropdown too
        if (query === '' && input.dataset.loadedDefault !== "true") {
            dropdown.innerHTML = '<div class="list-group-item text-muted small"><div class="spinner-border spinner-border-sm me-2" role="status"></div>Loading network...</div>';
            dropdown.classList.remove('d-none');
        }

        fetch(`/networks.json?query=${encodeURIComponent(query)}`)
            .then(response => {
                if (!response.ok) throw new Error('Network response was not ok');
                return response.json();
            })
            .then(data => {
                if (spinner) spinner.classList.add('d-none');
                renderDropdown(data, query);
                if (query === '') {
                    input.dataset.loadedDefault = "true";
                }
            })
            .catch(err => {
                console.error("Error fetching companies:", err);
                if (spinner) spinner.classList.add('d-none');
                dropdown.innerHTML = '<div class="list-group-item text-danger small">Error loading companies. Please try again.</div>';
                dropdown.classList.remove('d-none');
            });
    }

    function renderDropdown(data, query) {
        dropdown.innerHTML = '';

        const hasNetwork = data.network && data.network.length > 0;
        const hasOther = data.other && data.other.length > 0;

        if (!hasNetwork && !hasOther) {
            dropdown.innerHTML = '<div class="list-group-item text-muted small">No companies found</div>';
            dropdown.classList.remove('d-none');
            return;
        }

        if (hasNetwork) {
            const header = document.createElement('div');
            header.className = 'list-group-item bg-light fw-bold small text-muted py-1';
            header.textContent = 'MY NETWORK';
            dropdown.appendChild(header);

            data.network.forEach(company => {
                dropdown.appendChild(createItem(company, 'network'));
            });
        }

        if (hasOther) {
            const header = document.createElement('div');
            header.className = 'list-group-item bg-light fw-bold small text-muted py-1';
            header.textContent = 'SEARCH RESULTS';
            dropdown.appendChild(header);

            data.other.forEach(company => {
                dropdown.appendChild(createItem(company, 'other'));
            });
        }

        dropdown.classList.remove('d-none');
    }

    function createItem(company, type) {
        const a = document.createElement('a');
        a.href = "#";
        a.className = "list-group-item list-group-item-action p-2";
        a.innerHTML = `
        <div class="d-flex w-100 justify-content-between align-items-center">
            <h6 class="mb-0 fw-bold">${company.name || 'Unnamed'}</h6>
            ${type === 'network' ? '<span class="badge bg-success-subtle text-success-emphasis rounded-pill" style="font-size: 0.7em;">Connected</span>' : ''}
        </div>
        <small class="text-muted d-block text-truncate" style="max-width: 100%;">${company.address || 'No address'}</small>
      `;

        a.addEventListener('click', (e) => {
            e.preventDefault();
            selectCompany(company);
        });
        return a;
    }

    function selectCompany(company) {
        hiddenInput.value = company.id;

        updatePreview(company);

        selectorInterface.classList.add('d-none');
        preview.classList.remove('d-none');
        dropdown.classList.add('d-none');
    }

    function updatePreview(company) {
        document.getElementById('company_name').textContent = company.name || '';
        document.getElementById('company_address').textContent = company.address || '';
        document.getElementById('company_country').textContent = company.country || (company.address ? "Philippines" : "No country selected");
        document.getElementById('company_country').dataset.country = company.country || '';

        const companyIdStr = company.company_id_number || '-';
        const companyIdType = company.company_id_type || '';
        document.getElementById('company_number').textContent = `Company ${companyIdType} number : ${companyIdStr}`;

        const taxIdStr = company.tax_id_number || '-';
        const taxIdType = company.tax_id_type || '';
        document.getElementById('company_tax_number').textContent = `Tax ${taxIdType} number : ${taxIdStr}`;
    }

    if (changeBtn && !changeBtn.dataset.listenerAttached) {
        changeBtn.addEventListener('click', (e) => {
            e.preventDefault();
            preview.classList.add('d-none');
            selectorInterface.classList.remove('d-none');
            hiddenInput.value = '';
            input.value = '';
            setTimeout(() => input.focus(), 50);
        });
        changeBtn.dataset.listenerAttached = "true";
    }

    // Return cleanup function
    return function cleanup() {
        document.removeEventListener('click', clickHandler);
    };
}
