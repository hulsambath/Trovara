part of 'note_view.dart';

class _NoteContent extends StatelessWidget {
  const _NoteContent(this.viewModel);

  final NoteViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(viewModel.currentNote?.title ?? 'Untitled'),
      surfaceTintColor: Colors.transparent,
      actions: [
        UnifiedTagsIconButton(
          selectedActivityIds: viewModel.currentNote?.activityTags ?? [],
          selectedMoodIds: viewModel.currentNote?.moodTags ?? [],
          selectedTimeIds: viewModel.currentNote?.timeTags ?? [],
          selectedPersonalGrowthIds: viewModel.currentNote?.personalGrowthTags ?? [],
          selectedCustomTags: viewModel.currentNote?.customTagObjects.map((tag) => tag.name).toList() ?? [],
          onActivityChanged: viewModel.updateActivityTags,
          onMoodChanged: viewModel.updateMoodTags,
          onTimeChanged: viewModel.updateTimeTags,
          onPersonalGrowthChanged: viewModel.updatePersonalGrowthTags,
          onCustomTagsChanged: viewModel.updateCustomTags,
          creationTime: viewModel.currentNote?.createdAt,
          showTimeSuggestions: viewModel.isNewNote,
        ),
        if (viewModel.hasUnsavedChanges)
          IconButton(icon: const Icon(Icons.save), onPressed: () => viewModel.saveNote(), tooltip: 'Save'),
      ],
    ),
    body: Column(
      children: [
        Expanded(child: _buildBody(context)),
        _buildFooter(context),
      ],
    ),
  );

  Widget _buildBody(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: viewModel.titleController,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
        ),
        Expanded(
          child: QuillEditor(
            controller: viewModel.quillController,
            focusNode: viewModel.focusNode,
            scrollController: viewModel.scrollController,
            config: const QuillEditorConfig(),
          ),
        ),
      ],
    ),
  );

  Widget _buildFooter(BuildContext context) => Container(
    height: kToolbarHeight,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: _buildToolbar(context),
  );

  Widget _buildToolbar(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        QuillSimpleToolbar(
          controller: viewModel.quillController,
          config: QuillSimpleToolbarConfig(
            color: Theme.of(context).colorScheme.surface,
            buttonOptions: QuillSimpleToolbarButtonOptions(
              color: QuillToolbarColorButtonOptions(
                childBuilder: (dynamic options, dynamic extraOptions) {
                  extraOptions as QuillToolbarColorButtonExtraOptions;
                  return QuillToolbarColorButton(controller: extraOptions.controller, isBackground: false);
                },
              ),
              backgroundColor: QuillToolbarColorButtonOptions(
                childBuilder: (dynamic options, dynamic extraOptions) {
                  extraOptions as QuillToolbarColorButtonExtraOptions;
                  return QuillToolbarColorButton(controller: extraOptions.controller, isBackground: true);
                },
              ),
            ),
            multiRowsDisplay: true,
            showDividers: true,
            showFontFamily: false,
            showFontSize: false,
            showBoldButton: true,
            showItalicButton: true,
            showSmallButton: false,
            showUnderLineButton: true,
            showLineHeightButton: false,
            showStrikeThrough: true,
            showInlineCode: false,
            showColorButton: true,
            showBackgroundColorButton: true,
            showClearFormat: true,
            showAlignmentButtons: true,
            showLeftAlignment: true,
            showCenterAlignment: true,
            showRightAlignment: true,
            showJustifyAlignment: true,
            showHeaderStyle: false,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: true,
            showCodeBlock: false,
            showQuote: true,
            showIndent: true,
            showLink: true,
            showUndo: true,
            showRedo: true,
            showDirection: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showClipboardCut: false,
            showClipboardCopy: false,
            showClipboardPaste: false,
          ),
        ),
      ],
    ),
  );
}
