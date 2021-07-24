[ExtrasElement::] Extras Element.

To write the Extras element (Xt) in the index.

@

=
void ExtrasElement::render(OUTPUT_STREAM, localisation_dictionary *LD) {
	inter_tree *I = InterpretIndex::get_tree();
	tree_inventory *inv = Synoptic::inv(I);
	TreeLists::sort(inv->rulebook_nodes, Synoptic::module_order);
	TreeLists::sort(inv->activity_nodes, Synoptic::module_order);

	inter_package *E;
	LOOP_OVER_INVENTORY_PACKAGES(E, i, inv->module_nodes)
		if (Metadata::read_optional_numeric(E, I"^category") == 1)
			@<Index rulebooks occurring in this part of the source text@>;
	LOOP_OVER_INVENTORY_PACKAGES(E, i, inv->module_nodes)
		if (Metadata::read_optional_numeric(E, I"^category") == 2)
			@<Index rulebooks occurring in this part of the source text@>;
}

@<Index rulebooks occurring in this part of the source text@> =
	int c = 0;
	inter_package *rb_pack;
	LOOP_OVER_INVENTORY_PACKAGES(rb_pack, i, inv->rulebook_nodes)
		if (Synoptic::module_containing(rb_pack->package_head) == E) {
			if (Metadata::read_optional_numeric(rb_pack, I"^automatically_generated"))
				continue;
			if (c++ == 0) @<Heading for these@>;
			IndexRules::rulebook_box(OUT, inv, 
				Metadata::read_optional_textual(rb_pack, I"^printed_name"),
				NULL, rb_pack, NULL, 1, TRUE, LD);
		}
	inter_package *av_pack;
	LOOP_OVER_INVENTORY_PACKAGES(av_pack, i, inv->activity_nodes)
		if (Synoptic::module_containing(av_pack->package_head) == E) {
			if (c++ == 0) @<Heading for these@>;
			IndexRules::activity_box(OUT, I, av_pack, 1, LD);
		}

@<Heading for these@> =
	HTML_OPEN("p");
	if (Metadata::read_optional_numeric(E, I"^category") == 1) {
		WRITE("<b>From the source text</b>");
	} else {
		WRITE("<b>From the extension %S</b>",
			Metadata::read_optional_textual(E, I"^credit"));
	}
	HTML_CLOSE("p");