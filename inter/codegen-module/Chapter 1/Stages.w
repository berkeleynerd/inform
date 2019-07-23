[CodeGen::Stage::] Stages.

To create the stages through which code generation proceeds.

@h Stages.
Each possible pipeline stage is represented by a single instance of the
following. Some stages are invoked with an argument, often the filename to
write output to; others are not.

@e NO_STAGE_ARG from 1
@e GENERAL_STAGE_ARG
@e FILE_STAGE_ARG
@e TEXT_OUT_STAGE_ARG
@e EXT_FILE_STAGE_ARG
@e EXT_TEXT_OUT_STAGE_ARG
@e TEMPLATE_FILE_STAGE_ARG

=
typedef struct pipeline_stage {
	struct text_stream *stage_name;
	int (*execute)(void *);
	int stage_arg; /* one of the |*_ARG| values above */
	int takes_repository;
	MEMORY_MANAGEMENT
} pipeline_stage;

pipeline_stage *CodeGen::Stage::new(text_stream *name, int (*X)(struct pipeline_step *), int arg, int tr) {
	pipeline_stage *stage = CREATE(pipeline_stage);
	stage->stage_name = Str::duplicate(name);
	stage->execute = (int (*)(void *)) X;
	stage->stage_arg = arg;
	stage->takes_repository = tr;
	return stage;
}

@h Creation.
To add a new pipeline stage, put the code for it into a new section in
Chapter 2, and then add a call to its |create_pipeline_stage| routine
to the routine below.

=
int stages_made = FALSE;
void CodeGen::Stage::make_stages(void) {
	if (stages_made == FALSE) {
		stages_made = TRUE;
		CodeGen::Stage::new(I"stop", CodeGen::Stage::run_stop_stage, NO_STAGE_ARG, FALSE);

		CodeGen::Stage::new(I"read", CodeGen::Stage::run_read_stage, FILE_STAGE_ARG, TRUE);
		CodeGen::Stage::new(I"move", CodeGen::Stage::run_move_stage, GENERAL_STAGE_ARG, TRUE);
		CodeGen::Stage::new(I"mask", CodeGen::Stage::run_mask_stage, GENERAL_STAGE_ARG, TRUE);
		CodeGen::Stage::new(I"unmask", CodeGen::Stage::run_unmask_stage, NO_STAGE_ARG, FALSE);

		CodeGen::create_pipeline_stage();
		CodeGen::Assimilate::create_pipeline_stage();
		CodeGen::Eliminate::create_pipeline_stage();
		CodeGen::Externals::create_pipeline_stage();
		CodeGen::Labels::create_pipeline_stage();
		CodeGen::MergeTemplate::create_pipeline_stage();
		CodeGen::PLM::create_pipeline_stage();
		CodeGen::RCC::create_pipeline_stage();
		CodeGen::ReconcileVerbs::create_pipeline_stage();
		CodeGen::Uniqueness::create_pipeline_stage();
	}	
}

@ The "stop" stage is special, in that it always returns false, thus stopping
the pipeline:

=
int CodeGen::Stage::run_stop_stage(pipeline_step *step) {
	return FALSE;
}

int CodeGen::Stage::run_read_stage(pipeline_step *step) {
	filename *F = step->parsed_filename;
	if (Inter::Binary::test_file(F)) Inter::Binary::read(step->repository, F);
	else Inter::Textual::read(step->repository, F);
	return TRUE;
}

int CodeGen::Stage::run_move_stage(pipeline_step *step) {
	LOG("Arg is %S.\n", step->step_argument);
	match_results mr = Regexp::create_mr();
	inter_symbol *S = NULL;
	if (Regexp::match(&mr, step->step_argument, L"(%d):(%c+)")) {
		int from_rep = Str::atoi(mr.exp[0], 0);
		if (step->pipeline->repositories[from_rep] == NULL)
			internal_error("no such repository");
		S = Inter::SymbolsTables::url_name_to_symbol(
			step->pipeline->repositories[from_rep], NULL, mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
	if (S == NULL) internal_error("no such location");
	inter_package *pack = Inter::Package::which(S);
	if (pack == NULL) internal_error("not a package");

	if (trace_bin) WRITE_TO(STDOUT, "Move %S\n", pack->package_name->symbol_name);

	return TRUE;
}

int CodeGen::Stage::run_mask_stage(pipeline_step *step) {
	LOG("Arg is %S.\n", step->step_argument);
	inter_symbol *S = Inter::SymbolsTables::url_name_to_symbol(step->repository, NULL, step->step_argument);
	if (S == NULL) internal_error("no such location");
	inter_package *pack = Inter::Package::which(S);
	if (pack == NULL) internal_error("not a package");
	Inter::set_mask(step->repository, pack);
	return TRUE;
}

int CodeGen::Stage::run_unmask_stage(pipeline_step *step) {
	Inter::set_mask(step->repository, NULL);
	return TRUE;
}