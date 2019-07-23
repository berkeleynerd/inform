[CodeGen::MergeTemplate::] Linker.

To link inter from I7 with template code.

@h Link.

=
void CodeGen::MergeTemplate::create_pipeline_stage(void) {
	CodeGen::Stage::new(I"merge-template", CodeGen::MergeTemplate::run_pipeline_stage, TEMPLATE_FILE_STAGE_ARG, TRUE);	
}

int CodeGen::MergeTemplate::run_pipeline_stage(pipeline_step *step) {
	inter_package *main_package = Inter::Packages::main(step->repository);
	inter_bookmark IBM;
	if (main_package) IBM = Inter::Bookmarks::at_end_of_this_package(main_package);
	else IBM = Inter::Bookmarks::at_start_of_this_repository(step->repository);
	CodeGen::MergeTemplate::link(&IBM, step->step_argument, step->the_N, step->the_PP, NULL);
	return TRUE;
}

inter_symbols_table *link_search_list[10];
int link_search_list_len = 0;

void CodeGen::MergeTemplate::ensure_search_list(inter_tree *I) {
	if (link_search_list_len == 0) {
		if (template_package) {
			link_search_list[1] = Inter::Packages::scope(Inter::Packages::main(I));
			link_search_list[0] = Inter::Packages::scope(template_package);
			link_search_list_len = 2;
		} else {
			link_search_list[0] = Inter::Packages::scope(Inter::Packages::main(I));
			link_search_list_len = 1;
		}
	}
}

void CodeGen::MergeTemplate::link(inter_bookmark *IBM, text_stream *template_file, int N, pathname **PP, inter_package *owner) {
	if (IBM == NULL) internal_error("no inter to link with");
	inter_tree *I = Inter::Bookmarks::tree(IBM);
	Inter::traverse_tree(I, CodeGen::MergeTemplate::visitor, NULL, NULL, 0);

	if (template_package == NULL) internal_error("unable to find template");

	CodeGen::MergeTemplate::ensure_search_list(I);

	inter_bookmark link_bookmark =
		Inter::Bookmarks::at_end_of_this_package(template_package);

	I6T_kit kit = TemplateReader::kit_out(&link_bookmark, &(CodeGen::MergeTemplate::receive_raw),  &(CodeGen::MergeTemplate::receive_command), NULL);
	kit.no_i6t_file_areas = N;
	for (int i=0; i<N; i++) kit.i6t_files[i] = PP[i];
	TEMPORARY_TEXT(T);
	TemplateReader::I6T_file_intervene(T, EARLY_LINK_STAGE, NULL, NULL, &kit);
	CodeGen::MergeTemplate::receive_raw(T, &kit);
	DISCARD_TEXT(T);
	TemplateReader::extract(template_file, &kit);
}

void CodeGen::MergeTemplate::visitor(inter_tree *I, inter_frame P, void *state) {
	if (P.data[ID_IFLD] == LINK_IST) {
		text_stream *S1 = Inter::Frame::ID_to_text(&P, P.data[SEGMENT_LINK_IFLD]);
		text_stream *S2 = Inter::Frame::ID_to_text(&P, P.data[PART_LINK_IFLD]);
		text_stream *S3 = Inter::Frame::ID_to_text(&P, P.data[TO_RAW_LINK_IFLD]);
		text_stream *S4 = Inter::Frame::ID_to_text(&P, P.data[TO_SEGMENT_LINK_IFLD]);
		void *ref = Inter::Frame::ID_to_ref(&P, P.data[REF_LINK_IFLD]);
		TemplateReader::new_intervention((int) P.data[STAGE_LINK_IFLD], S1, S2, S3, S4, ref);
	}
}

dictionary *linkable_namespace = NULL;
int linkable_namespace_created = FALSE;

inter_symbol *CodeGen::MergeTemplate::find_in_namespace(inter_tree *I, text_stream *name) {
	if (linkable_namespace_created == FALSE) {
		linkable_namespace_created = TRUE;
		linkable_namespace = Dictionaries::new(512, FALSE);
		inter_package *main_package = Inter::Packages::main(I);
		if (main_package) {
			inter_frame D = Inter::Symbols::defining_frame(main_package->package_name);
			LOOP_THROUGH_INTER_CHILDREN(C, D) {
				if (C.data[ID_IFLD] == PACKAGE_IST) {
					inter_package *P = Inter::Package::defined_by_frame(C);
					if (Str::ne(P->package_name->symbol_name, I"template"))
						CodeGen::MergeTemplate::build_r(P);
				}
			}
			
		}
	}
	if (Dictionaries::find(linkable_namespace, name))
		return (inter_symbol *) Dictionaries::read_value(linkable_namespace, name);
	return NULL;
}

void CodeGen::MergeTemplate::build_r(inter_package *P) {
	CodeGen::MergeTemplate::build_only(P);
	inter_frame D = Inter::Symbols::defining_frame(P->package_name);
	LOOP_THROUGH_INTER_CHILDREN(C, D) {
		if (C.data[ID_IFLD] == PACKAGE_IST) {
			inter_package *Q = Inter::Package::defined_by_frame(C);
			CodeGen::MergeTemplate::build_r(Q);
		}
	}
}

void CodeGen::MergeTemplate::build_only(inter_package *P) {
	inter_symbols_table *T = Inter::Packages::scope(P);
	if (T) {
		for (int i=0; i<T->size; i++) {
			inter_symbol *S = T->symbol_array[i];
			if ((Inter::Symbols::is_defined(S)) && (S->equated_to == NULL) &&
				(Inter::Symbols::get_flag(S, MAKE_NAME_UNIQUE) == FALSE)) {
				text_stream *name = S->symbol_name;
				if (Str::len(S->translate_text) > 0) name = S->translate_text;
				Dictionaries::create(linkable_namespace, name);
				Dictionaries::write_value(linkable_namespace, name, (void *) S);
			}
		}
	}
}

inter_symbol *CodeGen::MergeTemplate::find_name(inter_tree *I, text_stream *S, int deeply) {
	for (int i=0; i<link_search_list_len; i++) {
		inter_symbol *symb = Inter::SymbolsTables::symbol_from_name_not_equating(link_search_list[i], S);
		if (symb) return symb;
	}
	if (deeply) {
		inter_symbol *symb = CodeGen::MergeTemplate::find_in_namespace(I, S);
		if (symb) return symb;
	}
	return NULL;
}

void CodeGen::MergeTemplate::log_search_path(void) {
	for (int i=0; i<link_search_list_len; i++) {
		LOG("Search %d: $4\n", i, link_search_list[i]);
	}
}

int link_pie_count = 0;

void CodeGen::MergeTemplate::guard(inter_error_message *ERR) {
	if (ERR) { Inter::Errors::issue(ERR); internal_error("inter error"); }
}

void CodeGen::MergeTemplate::entire_splat(inter_bookmark *IBM, text_stream *origin, text_stream *content, inter_t level, inter_symbol *code_block) {
	inter_t SID = Inter::Warehouse::create_text(Inter::Bookmarks::warehouse(IBM), Inter::Bookmarks::package(IBM));
	text_stream *glob_storage = Inter::get_text(Inter::Bookmarks::tree(IBM), SID);
	Str::copy(glob_storage, content);
	CodeGen::MergeTemplate::guard(Inter::Splat::new(IBM, code_block, SID, 0, level, 0, NULL));
}

@

@d IGNORE_WS_FILTER_BIT 1
@d DQUOTED_FILTER_BIT 2
@d SQUOTED_FILTER_BIT 4
@d COMMENTED_FILTER_BIT 8
@d ROUTINED_FILTER_BIT 16
@d CONTENT_ON_LINE_FILTER_BIT 32

@d SUBORDINATE_FILTER_BITS (COMMENTED_FILTER_BIT + SQUOTED_FILTER_BIT + DQUOTED_FILTER_BIT + ROUTINED_FILTER_BIT)

=
void CodeGen::MergeTemplate::receive_raw(text_stream *S, I6T_kit *kit) {
	text_stream *R = Str::new();
	int mode = IGNORE_WS_FILTER_BIT;
	LOOP_THROUGH_TEXT(pos, S) {
		wchar_t c = Str::get(pos);
		if ((c == 10) || (c == 13)) c = '\n';
		if (mode & IGNORE_WS_FILTER_BIT) {
			if ((c == '\n') || (Characters::is_whitespace(c))) continue;
			mode -= IGNORE_WS_FILTER_BIT;
		}
		if ((c == '!') && (!(mode & (DQUOTED_FILTER_BIT + SQUOTED_FILTER_BIT)))) {
			mode = mode | COMMENTED_FILTER_BIT;
		}
		if (mode & COMMENTED_FILTER_BIT) {
			if (c == '\n') {
				mode -= COMMENTED_FILTER_BIT;
				if (!(mode & CONTENT_ON_LINE_FILTER_BIT)) continue;
			}
			else continue;
		}
		if ((c == '[') && (!(mode & SUBORDINATE_FILTER_BITS))) {
			mode = mode | ROUTINED_FILTER_BIT;
		}
		if (mode & ROUTINED_FILTER_BIT) {
			if ((c == ']') && (!(mode & (DQUOTED_FILTER_BIT + SQUOTED_FILTER_BIT + COMMENTED_FILTER_BIT)))) mode -= ROUTINED_FILTER_BIT;
		}
		if ((c == '\'') && (!(mode & (DQUOTED_FILTER_BIT + COMMENTED_FILTER_BIT)))) {
			if (mode & SQUOTED_FILTER_BIT) mode -= SQUOTED_FILTER_BIT;
			else mode = mode | SQUOTED_FILTER_BIT;
		}
		if ((c == '\"') && (!(mode & (SQUOTED_FILTER_BIT + COMMENTED_FILTER_BIT)))) {
			if (mode & DQUOTED_FILTER_BIT) mode -= DQUOTED_FILTER_BIT;
			else mode = mode | DQUOTED_FILTER_BIT;
		}
		if (c != '\n') {
			if (Characters::is_whitespace(c) == FALSE) mode = mode | CONTENT_ON_LINE_FILTER_BIT;
		} else {
			if (mode & CONTENT_ON_LINE_FILTER_BIT) mode = mode - CONTENT_ON_LINE_FILTER_BIT;
			else if (!(mode & SUBORDINATE_FILTER_BITS)) continue;
		}
		PUT_TO(R, c);
		if ((c == ';') && (!(mode & SUBORDINATE_FILTER_BITS))) {
			CodeGen::MergeTemplate::chunked_raw(R, kit);
			mode = IGNORE_WS_FILTER_BIT;
		}
	}
	CodeGen::MergeTemplate::chunked_raw(R, kit);
	Str::clear(S);
}

void CodeGen::MergeTemplate::chunked_raw(text_stream *S, I6T_kit *kit) {
	if (Str::len(S) == 0) return;
	PUT_TO(S, '\n');
	CodeGen::MergeTemplate::entire_splat(kit->IBM, I"template", S, (inter_t) (Inter::Bookmarks::baseline(kit->IBM) + 1), Inter::Bookmarks::package(kit->IBM)->package_name);
	Str::clear(S);
}

void CodeGen::MergeTemplate::receive_command(OUTPUT_STREAM, text_stream *command, text_stream *argument, I6T_kit *kit) {
	if ((Str::eq_wide_string(command, L"plugin")) ||
		(Str::eq_wide_string(command, L"type")) ||
		(Str::eq_wide_string(command, L"open-file")) ||
		(Str::eq_wide_string(command, L"close-file")) ||
		(Str::eq_wide_string(command, L"lines")) ||
		(Str::eq_wide_string(command, L"endlines")) ||
		(Str::eq_wide_string(command, L"open-index")) ||
		(Str::eq_wide_string(command, L"close-index")) ||
		(Str::eq_wide_string(command, L"index-page")) ||
		(Str::eq_wide_string(command, L"index-element")) ||
		(Str::eq_wide_string(command, L"index")) ||
		(Str::eq_wide_string(command, L"log")) ||
		(Str::eq_wide_string(command, L"log-phase")) ||
		(Str::eq_wide_string(command, L"progress-stage")) ||
		(Str::eq_wide_string(command, L"counter")) ||
		(Str::eq_wide_string(command, L"value")) ||
		(Str::eq_wide_string(command, L"read-assertions")) ||
		(Str::eq_wide_string(command, L"callv")) ||
		(Str::eq_wide_string(command, L"call")) ||
		(Str::eq_wide_string(command, L"array")) ||
		(Str::eq_wide_string(command, L"marker")) ||
		(Str::eq_wide_string(command, L"testing-routine")) ||
		(Str::eq_wide_string(command, L"testing-command"))) {
		LOG("command: <%S> argument: <%S>\n", command, argument);
		TemplateReader::error("the template command '{-%S}' has been withdrawn in this version of Inform", command);
	} else {
		LOG("command: <%S> argument: <%S>\n", command, argument);
		TemplateReader::error("no such {-command} as '%S'", command);
	}
}