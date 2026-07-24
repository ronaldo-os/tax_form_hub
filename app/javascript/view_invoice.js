
$(document).on('click', '#download_button', function () {
    const originalInvoice = document.getElementById("invoice_card");
    if (!originalInvoice) return;

    const $trigger = $(this);
    if ($trigger.data('downloading')) return;
    $trigger.data('downloading', true);

    const isDarkMode = document.documentElement.getAttribute('data-theme') === 'dark' || document.documentElement.getAttribute('data-bs-theme') === 'dark';

    let $overlay = $('#pdf-loading-overlay');
    if (!$overlay.length) {
        $overlay = $(`
            <div id="pdf-loading-overlay" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; z-index: 999999; display: flex; flex-direction: column; justify-content: center; align-items: center;">
                <div class="spinner-border pdf-spinner" style="width: 4rem; height: 4rem;" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
                <h3 class="mt-4 pdf-text">Downloading PDF...</h3>
                <p class="pdf-subtext">Please do not close this window.</p>
            </div>
        `).appendTo('body');
    }

    if (isDarkMode) {
        $overlay.css({ 'background-color': '#212529', 'color': '#f8f9fa' });
        $overlay.find('.pdf-spinner').removeClass('text-primary').addClass('text-light');
        $overlay.find('.pdf-subtext').css('color', '#adb5bd');
    } else {
        $overlay.css({ 'background-color': '#ffffff', 'color': '#212529' });
        $overlay.find('.pdf-spinner').removeClass('text-light').addClass('text-primary');
        $overlay.find('.pdf-subtext').css('color', '#6c757d');
    }

    $overlay.show();

    // Clone the invoice to avoid modifying the visible page
    const clone = originalInvoice.cloneNode(true);

    // Create a temp container for the clone
    const temp = document.createElement('div');
    temp.classList.add('force-light-mode', 'invoice-card');
    temp.setAttribute('data-theme', 'light');
    temp.setAttribute('data-bs-theme', 'light');

    // Position off-screen but visible for rendering
    temp.style.position = 'absolute';
    temp.style.left = '-9999px';
    temp.style.top = '0';
    temp.style.width = '1000px'; // Set a fixed width for consistent PDF layout
    temp.style.background = 'white';
    temp.style.color = 'black';
    temp.style.opacity = '0';
    temp.style.pointerEvents = 'none';
    temp.appendChild(clone);
    document.body.appendChild(temp);

    let invoice = clone;

    // Create a clean container to replace the #invoice_card wrapper
    const content = document.createElement('div');

    // Move all children from invoice card to the clean container
    content.classList.add('invoice-card');
    while (invoice.firstChild) {
        content.appendChild(invoice.firstChild);
    }

    // Replace the original invoice card with the clean container in the DOM
    invoice.parentNode.replaceChild(content, invoice);

    // Update the invoice variable
    invoice = content;

    // Add page break classes to prevent content from being cut off
    const tableRows = invoice.querySelectorAll('table tr');
    tableRows.forEach(row => {
        row.style.pageBreakInside = 'avoid';
        row.style.breakInside = 'avoid';
    });

    const tables = invoice.querySelectorAll('table');
    tables.forEach(table => {
        table.style.pageBreakInside = 'auto';
    });

    const cards = invoice.querySelectorAll('.card');
    cards.forEach(card => {
        card.style.pageBreakInside = 'avoid';
        card.style.breakInside = 'avoid';
    });

    // Specific styling for PDF: remove card borders and bg-light from attachment sections
    const attachmentContainers = invoice.querySelectorAll('#attachments-section, #modal_new_attachments_preview, #persisted-attachments-container');
    attachmentContainers.forEach(container => {
        container.querySelectorAll('.card').forEach(card => {
            card.style.border = '1px solid white';
            card.style.boxShadow = 'none';
        });
        container.querySelectorAll('.bg-light').forEach(el => {
            el.classList.remove('bg-light');
            el.style.backgroundColor = 'transparent';
        });
    });

    // Always remove the Download button from attachment cards in the PDF
    invoice.querySelectorAll('a.btn.btn-outline-primary, a.btn.btn-sm.btn-outline-primary').forEach(btn => {
        if (btn.textContent.trim() === 'Download') {
            btn.remove();
        }
    });

    // Remove non-renderable elements (embed, object, iframe) that cause html2canvas to fail
    invoice.querySelectorAll('embed, object, iframe').forEach(el => el.remove());

    // Apply slight scaling as requested to prevent cropping
    invoice.style.transform = 'scale(0.99)';
    invoice.style.transformOrigin = 'top left';

    // Wait for all images to load before generating PDF
    const images = Array.from(invoice.querySelectorAll('img'));
    const imagePromises = images.map(img => {
        if (img.complete) return Promise.resolve();
        return new Promise(resolve => {
            img.onload = img.onerror = resolve;
        });
    });

    Promise.all(imagePromises).then(() => {
        // Get today's date in YYYY-MM-DD format
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        const dateStr = `${yyyy}-${mm}-${dd}`;

        const invoiceId = location.pathname.split('/').pop();

        const opt = {
            margin: [9, 9, 9, 9],
            filename: `${dateStr}-invoice-${invoiceId}.pdf`,
            image: { type: 'jpeg', quality: 0.98 },
            html2canvas: {
                scale: 1.5,
                useCORS: true,
                letterRendering: true,
                logging: false
            },
            jsPDF: {
                unit: 'pt',
                format: 'a4',
                orientation: 'portrait',
                compress: true
            },
            pagebreak: {
                mode: ['css', 'legacy'],
                after: '.page-break-after',
                avoid: ['tr', '.card', 'table', '.no-break']
            }
        };

        if (typeof html2pdf === 'undefined') {
            throw new Error('html2pdf is not available on the page');
        }

        const html = document.documentElement;
        const currentDataTheme = html.getAttribute('data-theme');
        const currentBSTheme = html.getAttribute('data-bs-theme');

        // Disable transitions temporarily to prevent animation during PDF capture
        const noTransitionStyle = document.createElement('style');
        noTransitionStyle.appendChild(
            document.createTextNode(
                `* {
                   -webkit-transition: none !important;
                   -moz-transition: none !important;
                   -o-transition: none !important;
                   -ms-transition: none !important;
                   transition: none !important;
                }`
            )
        );
        document.head.appendChild(noTransitionStyle);

        // Force light mode on root temporarily for high-fidelity capture
        html.setAttribute('data-theme', 'light');
        html.setAttribute('data-bs-theme', 'light');

        html2pdf().set(opt).from(invoice).save().then(() => {
            // Restore themes
            if (currentDataTheme) html.setAttribute('data-theme', currentDataTheme);
            else html.removeAttribute('data-theme');

            if (currentBSTheme) html.setAttribute('data-bs-theme', currentBSTheme);
            else html.removeAttribute('data-bs-theme');

            // Force repaint and restore transitions
            const _ = window.getComputedStyle(noTransitionStyle).opacity;
            if (document.head.contains(noTransitionStyle)) document.head.removeChild(noTransitionStyle);

            // Clean up
            if (document.body.contains(temp)) document.body.removeChild(temp);
        }).catch((error) => {
            console.error('Error generating PDF:', error);

            // Restore themes
            if (currentDataTheme) html.setAttribute('data-theme', currentDataTheme);
            else html.removeAttribute('data-theme');

            if (currentBSTheme) html.setAttribute('data-bs-theme', currentBSTheme);
            else html.removeAttribute('data-bs-theme');

            // Force repaint and restore transitions
            const _ = window.getComputedStyle(noTransitionStyle).opacity;
            if (document.head.contains(noTransitionStyle)) document.head.removeChild(noTransitionStyle);

            alert('Failed to generate PDF. Please check the console for details and try again.');
            if (document.body.contains(temp)) {
                document.body.removeChild(temp);
            }
        }).finally(() => {
            $trigger.data('downloading', false);
            $('#pdf-loading-overlay').hide();
        });
    }).catch((error) => {
        console.error('Error preparing PDF:', error);
        alert('Failed to prepare PDF. Please try again.');
        if (document.body.contains(temp)) document.body.removeChild(temp);
        $trigger.data('downloading', false);
        $('#pdf-loading-overlay').hide();
    });
});
