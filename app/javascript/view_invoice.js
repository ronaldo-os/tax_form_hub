
$(document).on('click', '#download_button', function () {
    const originalInvoice = document.getElementById("invoice_card");
    if (!originalInvoice) return;

    // Clone the invoice to avoid modifying the visible page
    const clone = originalInvoice.cloneNode(true);

    // Create a temp container for the clone
    const temp = document.createElement('div');
    // Position off-screen but visible for rendering
    temp.style.position = 'absolute';
    temp.style.left = '-9999px';
    temp.style.top = '0';
    temp.style.width = '100%'; // Ensure it has width
    temp.appendChild(clone);
    document.body.appendChild(temp);

    let invoice = clone;

    // Create a clean container to replace the #invoice_card wrapper
    const content = document.createElement('div');

    // Move all children from invoice card to the clean container
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

    // Get today's date in YYYY-MM-DD format
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const dateStr = `${yyyy}-${mm}-${dd}`;

    const invoiceId = location.pathname.split('/').pop();

    const opt = {
        margin: [10, 10, 10, 10],
        filename: `${dateStr}-invoice-${invoiceId}.pdf`,
        image: { type: 'jpeg', quality: 0.98 },
        html2canvas: {
            scale: 2,
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
            mode: ['avoid-all', 'css', 'legacy'],
            before: '.page-break-before',
            after: '.page-break-after',
            avoid: ['tr', '.card', 'table']
        }
    };

    html2pdf().set(opt).from(invoice).save().then(() => {
        // Clean up
        document.body.removeChild(temp);
    }).catch((error) => {
        console.error('Error generating PDF:', error);
        alert('Failed to generate PDF. Please try again.');
        if (document.body.contains(temp)) {
            document.body.removeChild(temp);
        }
    });
});
