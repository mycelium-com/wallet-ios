#import "PTableViewSource.h"

@implementation PTableViewSourceAttributes

- (void) inheritAttributesFrom:(PTableViewSourceAttributes*)other
{
    self.cellIdentifier            = other.cellIdentifier;
    self.cellStyle                 = other.cellStyle;
    self.selectionStyle            = other.selectionStyle;
    self.accessoryType             = other.accessoryType;
    self.editingAccessoryType      = other.editingAccessoryType;
    self.textAlignment             = other.textAlignment;
    self.minimumScaleFactor        = other.minimumScaleFactor;
    self.adjustsFontSizeToFitWidth = other.adjustsFontSizeToFitWidth;
    self.keyboardType              = other.keyboardType;
    self.returnKeyType             = other.returnKeyType;
    self.font                      = other.font;
    self.detailFont                = other.detailFont;
    self.textColor                 = other.textColor;
    self.detailTextColor           = other.detailTextColor;
    self.rowHeight                 = other.rowHeight;
    self.inputView                 = other.inputView;
    self.inputAccessoryView        = other.inputAccessoryView;
    
    self.action                    = other.action;
    self.segueIdentifier           = other.segueIdentifier;
    self.setupAction               = other.setupAction;
    self.labelForTextField         = other.labelForTextField;
    self.textFieldForEditing       = other.textFieldForEditing;
    self.canEditRow                = other.canEditRow;
    self.canMoveRow                = other.canMoveRow;
    self.willSelectAction          = other.willSelectAction;
    self.insertAction              = other.insertAction;
    self.deleteAction              = other.deleteAction;
    self.moveAction                = other.moveAction;
    self.moveTargetBlock           = other.moveTargetBlock;
}

@end


@interface PTableViewSourceSection ()
@property(nonatomic, weak, readwrite) PTableViewSource* source;
@end

@interface PTableViewSourceItem ()
@property(nonatomic, weak, readwrite) PTableViewSourceSection* section;
@end


@implementation PTableViewSource


- (id) init
{
    if (self = [super init])
    {
        self.rowHeight = UITableViewAutomaticDimension;
        self.selectionStyle = UITableViewCellSelectionStyleDefault; // default is iOS7-only.
    }
    return self;
}
- (void) addSection:(PTableViewSourceSection*) section
{
    if (!section) return;
    if (!_sections) _sections = @[];
    section.source = self;
    section.sectionIndex = _sections.count;
    _sections = [_sections arrayByAddingObject:section];
}

- (void) section:(void (^)(PTableViewSourceSection *))block
{
    PTableViewSourceSection* section = [PTableViewSourceSection new];
    [section inheritAttributesFrom:self];
    section.sectionIndex = _sections.count;
    block(section);
    [self addSection:section];
}

- (PTableViewSourceSection*) sectionAtIndex:(NSInteger)sectionIndex
{
    return _sections[sectionIndex];
}

- (PTableViewSourceItem*) itemAtIndexPath:(NSIndexPath*)itemIndexPath
{
    return [_sections[itemIndexPath.section] items][itemIndexPath.row];
}




#pragma mark - UITableViewDataSource & Delegate



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self sectionAtIndex:section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self itemAtIndexPath:indexPath];
	NSString* cellid = item.cellIdentifier ?: @"cell";
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellid];
	if (!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:item.cellStyle reuseIdentifier:cellid];
	}
    
    // TODO: do required customizations here
    cell.showsReorderControl = item.canMoveRow ? item.canMoveRow.boolValue : !!item.section.moveAction;
	
    if (item.setupAction)
    {
        item.setupAction(item, indexPath, cell);
    }
    else
    {
        [item setupCell:cell atIndexPath:indexPath];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self itemAtIndexPath:indexPath].rowHeight ?: tableView.rowHeight ?: UITableViewAutomaticDimension;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section    // fixed font style. use custom view (UILabel) if you want something different
{
    return [self sectionAtIndex:section].headerTitle;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [self sectionAtIndex:section].footerTitle;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [self sectionAtIndex:section].headerView.bounds.size.height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [self sectionAtIndex:section].footerView.bounds.size.height;
}

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [self sectionAtIndex:section].headerView;
}

- (UIView*) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [self sectionAtIndex:section].footerView;
}



// Selection


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self itemAtIndexPath:indexPath];
    if (!item.willSelectAction)
    {
        // Only select if has some action defined.
        return item.action ? indexPath : nil;
    }
    return item.willSelectAction(item, indexPath);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self itemAtIndexPath:indexPath];
    
//	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
//	self.selectedCellFrameInView = [self.view convertRect:cell.bounds fromView:cell];
    
//    BOOL deselectOnSecondTap = item.deselectOnSecondTap;
//    if (deselectOnSecondTap)
//    {
//        if ([self.editingIndexPathForTableView isEqual:indexPath])
//        {
//            self.editingIndexPath = nil;
//            return;
//        }
//    }
    
    if (item.action)
    {
        item.action(item, indexPath);
    }
    else if (item.segueIdentifier)
    {
        [self.viewController performSegueWithIdentifier:item.segueIdentifier sender:item];
    }
    
//	// Scroll later because the insets update happens also later (see keyboard notifications).
//	dispatch_async(dispatch_get_main_queue(), ^{
//		[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
//	});
}



// Editing

// Individual rows can opt out of having the -editing property set for them. If not implemented, all rows are assumed to be editable.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self itemAtIndexPath:indexPath];
    if (item.canEditRow)
    {
        return item.canEditRow.boolValue;
    }
    return item.deleteAction || item.insertAction;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self itemAtIndexPath:indexPath];
    
    if (item.deleteAction) return UITableViewCellEditingStyleDelete;
    if (item.insertAction) return UITableViewCellEditingStyleInsert;
    
	return UITableViewCellEditingStyleNone;
}

// After a row has the minus or plus button invoked (based on the UITableViewCellEditingStyle for the cell), the dataSource must commit the change
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self itemAtIndexPath:indexPath];
    
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        if (item.deleteAction) item.deleteAction(item, indexPath);
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert)
    {
        if (item.insertAction) item.insertAction(item, indexPath);
    }
}


// Data manipulation - reorder / moving support

// Allows the reorder accessory view to optionally be shown for a particular row. By default, the reorder control will be shown only if the datasource implements -tableView:moveRowAtIndexPath:toIndexPath:
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self itemAtIndexPath:indexPath].canMoveRow)
    {
        return [self itemAtIndexPath:indexPath].canMoveRow.boolValue;
    }
    return !![self sectionAtIndex:indexPath.section].moveAction;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    PTableViewSourceSection* section = [self sectionAtIndex:sourceIndexPath.section];
	if (section.moveAction) section.moveAction([self itemAtIndexPath:sourceIndexPath], sourceIndexPath, destinationIndexPath);
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    PTableViewSourceSection* section = [self sectionAtIndex:sourceIndexPath.section];
    
    if (section.moveTargetBlock) return section.moveTargetBlock([self itemAtIndexPath:sourceIndexPath], sourceIndexPath, proposedDestinationIndexPath);

    // By default, do not move.
	return sourceIndexPath;
}



// Index - NOT IMPLEMENTED YET

//- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView                                                    // return list of section titles to display in section index view (e.g. "ABCD...Z#")
//{
//    [_sections valueForKey:@"indexTitle"];
//}
//
//- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
//{
//    // Default implementation is to
//
//}




@end


@implementation PTableViewSourceSection

+ (PTableViewSourceSection*) section:(void(^)(PTableViewSourceSection* section))block
{
    PTableViewSourceSection* section = [self new];
    block(section);
    return section;
}

- (void) addItem:(PTableViewSourceItem *)item
{
    if (!item) return;
    if (!_items) _items = @[];
    item.section = self;
    item.rowIndex = _items.count;
    _items = [_items arrayByAddingObject:item];
}

- (void) item:(void (^)(PTableViewSourceItem *))block
{
    PTableViewSourceItem* item = [PTableViewSourceItem new];
    
    [item inheritAttributesFrom:self];
    item.rowIndex = _items.count;
    block(item);
    [self addItem:item];
}

- (PTableViewSourceItem*) itemAtIndex:(NSInteger)itemIndex
{
    return _items[itemIndex];
}

@end



@implementation PTableViewSourceItem

+ (PTableViewSourceItem*) item:(void(^)(PTableViewSourceItem* section))block
{
    PTableViewSourceItem* item = [self new];
    block(item);
    return item;
}

- (void) setupCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    cell.selectionStyle = self.selectionStyle;
    cell.accessoryType = self.accessoryType;
    cell.editingAccessoryType = self.editingAccessoryType;
    cell.textLabel.textAlignment = self.textAlignment;
    
	cell.textLabel.text = self.title ?: @"";
    cell.detailTextLabel.text = self.detailTitle ?: @"";

    if (cell.detailTextLabel.text.length == 0)
    {
        cell.detailTextLabel.text = @" "; // so that the frame is not 0x0; we will strip the space when transforming into the editing textfield
    }
    
    if (self.font) cell.textLabel.font = self.font;
    if (self.detailFont) cell.detailTextLabel.font = self.detailFont;
    
    cell.textLabel.adjustsFontSizeToFitWidth = self.adjustsFontSizeToFitWidth;
    cell.textLabel.minimumScaleFactor = self.minimumScaleFactor;
    
    cell.textLabel.textColor = self.textColor;
    cell.detailTextLabel.textColor = self.detailTextColor;
}

@end

